#!/bin/bash
#
# Emergency Migration Script for Failing ClickHouse Server
# Handles 300GB+ migrations with resume capability and error handling
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MIGRATION_DIR="/migration/emergency"
BATCH_SIZE=1000000
VPS_B_HOST=""
VPS_B_USER="root"
LOG_FILE="${MIGRATION_DIR}/emergency-migration.log"
FAILED_LOG="${MIGRATION_DIR}/failed-tables.log"
MIGRATED_LOG="${MIGRATION_DIR}/migrated-tables.log"

# Functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }

# Show help
usage() {
    cat << EOF
Emergency Migration Script for Failing ClickHouse Server

Usage: $0 [OPTIONS] [command]

Commands:
    assess              Assess ClickHouse status and list tables
    export TABLE        Export single table with resume capability
    export-all          Export all tables with priority order
    copy-files          Direct file copy (if ClickHouse won't start)
    verify              Verify migrated data on VPS B
    resume              Resume failed migrations

Options:
    -h, --host HOST     VPS B hostname or IP
    -u, --user USER     VPS B SSH user (default: root)
    -b, --batch SIZE    Batch size for exports (default: 1000000)
    -d, --dir DIR       Migration directory (default: /migration/emergency)
    --help              Show this help

Examples:
    # Assess ClickHouse status
    sudo $0 assess

    # Export single table
    sudo $0 export production.orders

    # Export all tables
    sudo $0 export-all --host vps-b.example.com

    # Direct file copy
    sudo $0 copy-files --host vps-b.example.com

    # Verify migration
    sudo $0 verify --host vps-b.example.com

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host) VPS_B_HOST="$2"; shift 2 ;;
        -u|--user) VPS_B_USER="$2"; shift 2 ;;
        -b|--batch) BATCH_SIZE="$2"; shift 2 ;;
        -d|--dir) MIGRATION_DIR="$2"; shift 2 ;;
        --help) usage; exit 0 ;;
        *) COMMAND="$1"; shift ;;
    esac
done

# Setup
mkdir -p "$MIGRATION_DIR"
touch "$LOG_FILE"
touch "$FAILED_LOG"
touch "$MIGRATED_LOG"

# Command: Assess
assess() {
    log "Assessing ClickHouse status..."
    
    # Check if ClickHouse is running
    if systemctl is-active --quiet clickhouse-server; then
        success "ClickHouse is running"
        
        # Get version
        VERSION=$(clickhouse-client --secure --port 9440 -q "SELECT version()" 2>/dev/null || echo "unknown")
        log "ClickHouse version: $VERSION"
        
        # List databases and tables
        log "Getting list of tables..."
        clickhouse-client --secure --port 9440 -q "SELECT concat(database, '.', name) as table FROM system.tables WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') ORDER BY database, name FORMAT TSV" > "${MIGRATION_DIR}/tables.txt"
        
        TOTAL_TABLES=$(wc -l < "${MIGRATION_DIR}/tables.txt")
        log "Total tables found: $TOTAL_TABLES"
        
        # Get sizes
        log "Getting table sizes..."
        clickhouse-client --secure --port 9440 -q "SELECT 
            database, 
            table, 
            sum(rows) as rows, 
            formatReadableSize(sum(bytes)) as size,
            sum(bytes) as bytes
        FROM system.parts 
        WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') 
        AND active
        GROUP BY database, table 
        ORDER BY bytes DESC
        FORMAT TSV" > "${MIGRATION_DIR}/table-sizes.txt"
        
        echo ""
        echo "Table sizes (top 20):"
        head -20 "${MIGRATION_DIR}/table-sizes.txt" | column -t
        
        # Calculate total size
        TOTAL_BYTES=$(awk '{sum+=$5} END {print sum}' "${MIGRATION_DIR}/table-sizes.txt")
        TOTAL_SIZE=$(numfmt --to=iec $TOTAL_BYTES 2>/dev/null || echo "$TOTAL_BYTES bytes")
        log "Total data size: $TOTAL_SIZE"
        
    else
        error "ClickHouse is not running!"
        warning "You may need to use 'copy-files' command instead"
        
        # Check data directory
        if [ -d "/var/lib/clickhouse/data" ]; then
            DATA_SIZE=$(du -sh /var/lib/clickhouse/data 2>/dev/null | cut -f1)
            log "Raw data directory size: $DATA_SIZE"
        fi
    fi
}

# Command: Export single table
export_table() {
    local full_table=$1
    local database=${full_table%%.*}
    local table=${full_table#*.}
    
    log "=========================================="
    log "Exporting: $full_table"
    log "=========================================="
    
    # Check if already migrated
    if grep -q "^${full_table}$" "$MIGRATED_LOG"; then
        warning "Already migrated: $full_table (skipping)"
        return 0
    fi
    
    # Create directory for this table
    TABLE_DIR="${MIGRATION_DIR}/${database}/${table}"
    mkdir -p "$TABLE_DIR"
    
    # Get schema
    log "Getting schema for $full_table..."
    if ! clickhouse-client --secure --port 9440 -q "SHOW CREATE TABLE $full_table" > "${TABLE_DIR}/schema.sql" 2>"${TABLE_DIR}/schema.error"; then
        error "Cannot get schema for $full_table"
        cat "${TABLE_DIR}/schema.error" >> "$FAILED_LOG"
        echo "$full_table" >> "$FAILED_LOG"
        return 1
    fi
    
    # Get row count
    TOTAL_ROWS=$(clickhouse-client --secure --port 9440 -q "SELECT count() FROM $full_table" 2>/dev/null || echo "0")
    log "Total rows: $TOTAL_ROWS"
    
    if [ "$TOTAL_ROWS" -eq 0 ]; then
        warning "Table $full_table is empty"
        echo "$full_table" >> "$MIGRATED_LOG"
        return 0
    fi
    
    # Export data in batches
    local offset=0
    local batch=1
    local success=true
    
    while [ $offset -lt $TOTAL_ROWS ]; do
        log "Exporting batch $batch (offset: $offset, limit: $BATCH_SIZE)"
        
        local output_file="${TABLE_DIR}/batch_${batch}.tsv.gz"
        
        # Check if batch already exists
        if [ -f "$output_file" ] && [ -s "$output_file" ]; then
            log "Batch $batch already exists, skipping"
            offset=$((offset + BATCH_SIZE))
            batch=$((batch + 1))
            continue
        fi
        
        # Export batch
        if clickhouse-client --secure --port 9440 -q "SELECT * FROM $full_table LIMIT $BATCH_SIZE OFFSET $offset FORMAT TSV" 2>"${TABLE_DIR}/batch_${batch}.error" | gzip > "$output_file"; then
            
            # Verify export
            if [ -s "$output_file" ]; then
                BATCH_ROWS=$(zcat "$output_file" | wc -l)
                log "Batch $batch exported: $BATCH_ROWS rows"
                
                # Transfer to VPS B if host specified
                if [ -n "$VPS_B_HOST" ]; then
                    log "Transferring batch $batch to VPS B..."
                    if scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "$output_file" "${VPS_B_USER}@${VPS_B_HOST}:${TABLE_DIR}/" 2>"${TABLE_DIR}/scp_${batch}.error"; then
                        log "Batch $batch transferred successfully"
                        rm "$output_file"
                    else
                        error "Failed to transfer batch $batch"
                        success=false
                        break
                    fi
                fi
                
                offset=$((offset + BATCH_SIZE))
                batch=$((batch + 1))
            else
                error "Batch $batch is empty"
                success=false
                break
            fi
        else
            error "Failed to export batch $batch"
            cat "${TABLE_DIR}/batch_${batch}.error" >> "$FAILED_LOG"
            success=false
            break
        fi
        
        # Add delay to reduce load on failing server
        sleep 2
    done
    
    # Copy schema to VPS B
    if [ -n "$VPS_B_HOST" ] && [ "$success" = true ]; then
        scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${TABLE_DIR}/schema.sql" "${VPS_B_USER}@${VPS_B_HOST}:${TABLE_DIR}/"
    fi
    
    if [ "$success" = true ]; then
        echo "$full_table" >> "$MIGRATED_LOG"
        success "Successfully migrated: $full_table"
        return 0
    else
        error "Migration failed for: $full_table"
        echo "$full_table" >> "$FAILED_LOG"
        return 1
    fi
}

# Command: Export all tables
export_all() {
    log "Starting export of all tables..."
    
    if [ ! -f "${MIGRATION_DIR}/tables.txt" ]; then
        log "Table list not found. Running assessment first..."
        assess
    fi
    
    local total=$(wc -l < "${MIGRATION_DIR}/tables.txt")
    local current=0
    
    while IFS= read -r table; do
        current=$((current + 1))
        log "[$current/$total] Processing: $table"
        
        export_table "$table" || true
        
        # Add delay between tables
        sleep 5
    done < "${MIGRATION_DIR}/tables.txt"
    
    # Summary
    log "=========================================="
    log "Migration Summary"
    log "=========================================="
    log "Total tables: $total"
    log "Migrated: $(wc -l < "$MIGRATED_LOG")"
    log "Failed: $(wc -l < "$FAILED_LOG")"
    
    if [ -s "$FAILED_LOG" ]; then
        warning "Some tables failed to migrate. Check $FAILED_LOG"
        log "To retry failed tables, run: $0 resume"
    fi
}

# Command: Direct file copy
copy_files() {
    log "Starting direct file copy..."
    
    if [ -z "$VPS_B_HOST" ]; then
        error "VPS B host is required for copy-files command"
        usage
        exit 1
    fi
    
    warning "This method requires same ClickHouse version on both servers"
    warning "Some data may be lost if files are corrupted"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "Aborted"
        exit 0
    fi
    
    # Stop ClickHouse if running
    if systemctl is-active --quiet clickhouse-server; then
        log "Stopping ClickHouse..."
        systemctl stop clickhouse-server
    fi
    
    # Copy data files
    log "Copying data files to VPS B..."
    rsync -avz --progress --bwlimit=0 \
        -e "ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no" \
        /var/lib/clickhouse/ \
        "${VPS_B_USER}@${VPS_B_HOST}:/var/lib/clickhouse/" 2>&1 | tee -a "$LOG_FILE"
    
    # Copy config
    log "Copying configuration..."
    rsync -avz \
        -e "ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no" \
        /etc/clickhouse-server/ \
        "${VPS_B_USER}@${VPS_B_HOST}:/etc/clickhouse-server/"
    
    success "File copy complete!"
    log "SSH to VPS B and run:"
    log "  sudo chown -R clickhouse:clickhouse /var/lib/clickhouse/"
    log "  sudo systemctl start clickhouse-server"
}

# Command: Verify migration
verify_migration() {
    log "Verifying migration on VPS B..."
    
    if [ -z "$VPS_B_HOST" ]; then
        error "VPS B host is required for verify command"
        exit 1
    fi
    
    # Get row counts from both servers
    log "Getting row counts from VPS A..."
    clickhouse-client --secure --port 9440 -q "SELECT 
        concat(database, '.', table) as table,
        sum(rows) as rows
    FROM system.parts 
    WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') 
    AND active
    GROUP BY database, table
    FORMAT TSV" > "${MIGRATION_DIR}/vps-a-counts.txt" 2>/dev/null || error "Cannot connect to VPS A"
    
    log "Getting row counts from VPS B..."
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${VPS_B_USER}@${VPS_B_HOST}" \
        "clickhouse-client --secure --port 9440 -q \"SELECT 
            concat(database, '.', table) as table,
            sum(rows) as rows
        FROM system.parts 
        WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') 
        AND active
        GROUP BY database, table
        FORMAT TSV\"" > "${MIGRATION_DIR}/vps-b-counts.txt" 2>/dev/null || error "Cannot connect to VPS B"
    
    # Compare
    log "=========================================="
    log "Verification Results"
    log "=========================================="
    
    echo "Tables with mismatched row counts:"
    comm -3 <(sort "${MIGRATION_DIR}/vps-a-counts.txt") <(sort "${MIGRATION_DIR}/vps-b-counts.txt") | tee "${MIGRATION_DIR}/mismatched.txt"
    
    if [ ! -s "${MIGRATION_DIR}/mismatched.txt" ]; then
        success "All tables verified successfully!"
    else
        warning "Some tables have mismatched row counts. Review ${MIGRATION_DIR}/mismatched.txt"
    fi
}

# Command: Resume failed migrations
resume_failed() {
    log "Resuming failed migrations..."
    
    if [ ! -s "$FAILED_LOG" ]; then
        success "No failed migrations to resume"
        return 0
    fi
    
    log "Retrying $(wc -l < "$FAILED_LOG") failed tables with smaller batches..."
    BATCH_SIZE=10000  # Smaller batch for retry
    
    while IFS= read -r table; do
        if [ -n "$table" ]; then
            log "Retrying: $table"
            export_table "$table" || true
        fi
    done < "$FAILED_LOG"
    
    # Clear failed log
    > "$FAILED_LOG"
}

# Main
main() {
    case "${COMMAND:-}" in
        assess)
            assess
            ;;
        export)
            if [ -z "${2:-}" ]; then
                error "Table name required"
                usage
                exit 1
            fi
            export_table "$2"
            ;;
        export-all)
            export_all
            ;;
        copy-files)
            copy_files
            ;;
        verify)
            verify_migration
            ;;
        resume)
            resume_failed
            ;;
        *)
            error "Unknown command: ${COMMAND:-}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
