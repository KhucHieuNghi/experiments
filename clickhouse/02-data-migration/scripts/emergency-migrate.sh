#!/bin/bash
#
# Emergency Migration Script for Failing ClickHouse Server
# Handles 300GB+ migrations with resume capability and error handling
# Migrates: tables, views, materialized views, dictionaries, users, roles, grants
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
COMMAND=""
TABLE_ARG=""

# Functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }

# ClickHouse client wrapper
ch_query() {
    clickhouse-client --secure --port 9440 -q "$1" 2>/dev/null
}

ch_query_raw() {
    clickhouse-client --secure --port 9440 -q "$1"
}

# Show help
usage() {
    cat << EOF
Emergency Migration Script for Failing ClickHouse Server

Usage: $0 [OPTIONS] [command]

Commands:
    assess              Assess ClickHouse status and list all objects
    export TABLE        Export single table with resume capability
    export-all          Export all objects (tables, views, MVs, dicts, users)
    import              Import all migrated data on VPS B (run on VPS B)
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

    # Export all objects to VPS B
    sudo $0 export-all --host vps-b.example.com

    # Import on VPS B (run this ON VPS B)
    sudo $0 import

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
        *)
            if [ -z "$COMMAND" ]; then
                COMMAND="$1"
            elif [ -z "$TABLE_ARG" ]; then
                TABLE_ARG="$1"
            fi
            shift
            ;;
    esac
done

# Re-derive log paths after potential MIGRATION_DIR override
LOG_FILE="${MIGRATION_DIR}/emergency-migration.log"
FAILED_LOG="${MIGRATION_DIR}/failed-tables.log"
MIGRATED_LOG="${MIGRATION_DIR}/migrated-tables.log"

# Setup
mkdir -p "$MIGRATION_DIR"
touch "$LOG_FILE"
touch "$FAILED_LOG"
touch "$MIGRATED_LOG"

# ============================================================
# Command: Assess
# ============================================================
assess() {
    log "Assessing ClickHouse status..."
    
    # Check if ClickHouse is running
    if systemctl is-active --quiet clickhouse-server; then
        success "ClickHouse is running"
        
        # Get version
        VERSION=$(ch_query "SELECT version()" || echo "unknown")
        log "ClickHouse version: $VERSION"
        
        # ---- Classify all objects by engine type ----
        log "Classifying all database objects..."
        
        # Data tables (MergeTree, Log, Memory, etc. — anything with data)
        ch_query "SELECT concat(database, '.', name) FROM system.tables WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') AND engine NOT IN ('View', 'MaterializedView', 'Dictionary') AND engine != '' ORDER BY database, name FORMAT TSV" > "${MIGRATION_DIR}/data-tables.txt" 2>/dev/null || touch "${MIGRATION_DIR}/data-tables.txt"
        
        # Views (schema-only, no data)
        ch_query "SELECT concat(database, '.', name) FROM system.tables WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') AND engine = 'View' ORDER BY database, name FORMAT TSV" > "${MIGRATION_DIR}/views.txt" 2>/dev/null || touch "${MIGRATION_DIR}/views.txt"
        
        # Materialized Views (schema + data in target table)
        ch_query "SELECT concat(database, '.', name) FROM system.tables WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') AND engine = 'MaterializedView' ORDER BY database, name FORMAT TSV" > "${MIGRATION_DIR}/materialized-views.txt" 2>/dev/null || touch "${MIGRATION_DIR}/materialized-views.txt"
        
        # Dictionaries
        ch_query "SELECT concat(database, '.', name) FROM system.tables WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') AND engine = 'Dictionary' ORDER BY database, name FORMAT TSV" > "${MIGRATION_DIR}/dictionaries.txt" 2>/dev/null || touch "${MIGRATION_DIR}/dictionaries.txt"
        
        # Combined list for backward compat (all objects)
        cat "${MIGRATION_DIR}/data-tables.txt" "${MIGRATION_DIR}/views.txt" "${MIGRATION_DIR}/materialized-views.txt" "${MIGRATION_DIR}/dictionaries.txt" > "${MIGRATION_DIR}/tables.txt"
        
        # Databases list
        ch_query "SELECT name FROM system.databases WHERE name NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA', 'default') ORDER BY name FORMAT TSV" > "${MIGRATION_DIR}/databases.txt" 2>/dev/null || touch "${MIGRATION_DIR}/databases.txt"
        
        # Summary counts
        log "Objects found:"
        log "  Data tables:        $(wc -l < "${MIGRATION_DIR}/data-tables.txt" | tr -d ' ')"
        log "  Views:              $(wc -l < "${MIGRATION_DIR}/views.txt" | tr -d ' ')"
        log "  Materialized Views: $(wc -l < "${MIGRATION_DIR}/materialized-views.txt" | tr -d ' ')"
        log "  Dictionaries:       $(wc -l < "${MIGRATION_DIR}/dictionaries.txt" | tr -d ' ')"
        log "  Databases:          $(wc -l < "${MIGRATION_DIR}/databases.txt" | tr -d ' ')"
        
        # Get sizes for data tables
        log "Getting table sizes..."
        ch_query "SELECT 
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
        FORMAT TSV" > "${MIGRATION_DIR}/table-sizes.txt" 2>/dev/null || touch "${MIGRATION_DIR}/table-sizes.txt"
        
        echo ""
        echo "Table sizes (top 20):"
        head -20 "${MIGRATION_DIR}/table-sizes.txt" | column -t
        
        # Calculate total size
        TOTAL_BYTES=$(awk '{sum+=$5} END {print sum}' "${MIGRATION_DIR}/table-sizes.txt" 2>/dev/null || echo "0")
        TOTAL_SIZE=$(numfmt --to=iec "$TOTAL_BYTES" 2>/dev/null || echo "$TOTAL_BYTES bytes")
        log "Total data size: $TOTAL_SIZE"
        
        # Export users/roles info
        log "Checking users and roles..."
        local user_count
        user_count=$(ch_query "SELECT count() FROM system.users WHERE name NOT IN ('default')" || echo "0")
        local role_count
        role_count=$(ch_query "SELECT count() FROM system.roles" || echo "0")
        log "  Users: $user_count"
        log "  Roles: $role_count"
        
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

# ============================================================
# Get engine type for a table
# ============================================================
get_engine_type() {
    local full_table=$1
    local database=${full_table%%.*}
    local table=${full_table#*.}
    ch_query "SELECT engine FROM system.tables WHERE database = '${database}' AND name = '${table}'" || echo "Unknown"
}

# ============================================================
# Command: Export single table (handles all object types)
# ============================================================
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
    
    # Detect engine type
    local engine
    engine=$(get_engine_type "$full_table")
    echo "$engine" > "${TABLE_DIR}/engine.txt"
    log "Engine: $engine"
    
    # Get schema
    log "Getting schema for $full_table..."
    if ! ch_query_raw "SHOW CREATE TABLE $full_table" > "${TABLE_DIR}/schema.sql" 2>"${TABLE_DIR}/schema.error"; then
        error "Cannot get schema for $full_table"
        error "  Error: $(cat "${TABLE_DIR}/schema.error" 2>/dev/null)"
        echo "$full_table" >> "$FAILED_LOG"
        return 1
    fi
    
    # ---- Schema-only objects: Views, Materialized Views, Dictionaries ----
    if [ "$engine" = "View" ] || [ "$engine" = "MaterializedView" ] || [ "$engine" = "Dictionary" ]; then
        log "$full_table is a $engine — schema exported (no data export needed)"
        
        # Transfer schema to VPS B if host specified
        if [ -n "$VPS_B_HOST" ]; then
            ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${VPS_B_USER}@${VPS_B_HOST}" "mkdir -p '${TABLE_DIR}'"
            scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${TABLE_DIR}/schema.sql" "${VPS_B_USER}@${VPS_B_HOST}:${TABLE_DIR}/"
            scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${TABLE_DIR}/engine.txt" "${VPS_B_USER}@${VPS_B_HOST}:${TABLE_DIR}/"
        fi
        
        echo "$full_table" >> "$MIGRATED_LOG"
        success "Schema exported: $full_table ($engine)"
        return 0
    fi
    
    # ---- Data tables: export schema + data ----
    # Get row count
    TOTAL_ROWS=$(ch_query "SELECT count() FROM $full_table" || echo "0")
    log "Total rows: $TOTAL_ROWS"
    
    if [ "$TOTAL_ROWS" -eq 0 ]; then
        warning "Table $full_table is empty"
        
        if [ -n "$VPS_B_HOST" ]; then
            ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${VPS_B_USER}@${VPS_B_HOST}" "mkdir -p '${TABLE_DIR}'"
            scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${TABLE_DIR}/schema.sql" "${VPS_B_USER}@${VPS_B_HOST}:${TABLE_DIR}/"
            scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${TABLE_DIR}/engine.txt" "${VPS_B_USER}@${VPS_B_HOST}:${TABLE_DIR}/"
        fi
        
        echo "$full_table" >> "$MIGRATED_LOG"
        return 0
    fi
    
    # Export data in batches
    local offset=0
    local batch=1
    local export_success=true
    
    while [ $offset -lt $TOTAL_ROWS ]; do
        log "Exporting batch $batch (offset: $offset, limit: $BATCH_SIZE)"
        
        local output_file="${TABLE_DIR}/batch_${batch}.native.gz"
        
        # Check if batch already exists
        if [ -f "$output_file" ] && [ -s "$output_file" ]; then
            log "Batch $batch already exists, skipping"
            offset=$((offset + BATCH_SIZE))
            batch=$((batch + 1))
            continue
        fi
        
        # Export batch
        if ch_query_raw "SELECT * FROM $full_table LIMIT $BATCH_SIZE OFFSET $offset FORMAT Native" 2>"${TABLE_DIR}/batch_${batch}.error" | gzip > "$output_file"; then
            
            # Verify export
            if [ -s "$output_file" ]; then
                FILE_SIZE=$(du -h "$output_file" | cut -f1)
                log "Batch $batch exported: ${FILE_SIZE} compressed"
                
                # Transfer to VPS B if host specified
                if [ -n "$VPS_B_HOST" ]; then
                    log "Transferring batch $batch to VPS B..."
                    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${VPS_B_USER}@${VPS_B_HOST}" "mkdir -p '${TABLE_DIR}'"
                    if scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "$output_file" "${VPS_B_USER}@${VPS_B_HOST}:${TABLE_DIR}/" 2>"${TABLE_DIR}/scp_${batch}.error"; then
                        log "Batch $batch transferred successfully"
                        rm "$output_file"
                    else
                        error "Failed to transfer batch $batch"
                        export_success=false
                        break
                    fi
                fi
                
                offset=$((offset + BATCH_SIZE))
                batch=$((batch + 1))
            else
                error "Batch $batch is empty"
                export_success=false
                break
            fi
        else
            error "Failed to export batch $batch"
            error "  Error: $(cat "${TABLE_DIR}/batch_${batch}.error" 2>/dev/null)"
            export_success=false
            break
        fi
        
        # Add delay to reduce load on failing server
        sleep 2
    done
    
    # Copy schema + engine info to VPS B
    if [ -n "$VPS_B_HOST" ] && [ "$export_success" = true ]; then
        scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${TABLE_DIR}/schema.sql" "${VPS_B_USER}@${VPS_B_HOST}:${TABLE_DIR}/"
        scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${TABLE_DIR}/engine.txt" "${VPS_B_USER}@${VPS_B_HOST}:${TABLE_DIR}/"
    fi
    
    if [ "$export_success" = true ]; then
        echo "$full_table" >> "$MIGRATED_LOG"
        success "Successfully migrated: $full_table"
        return 0
    else
        error "Migration failed for: $full_table"
        echo "$full_table" >> "$FAILED_LOG"
        return 1
    fi
}

# ============================================================
# Command: Export users, roles, and grants
# ============================================================
export_access_control() {
    log "Exporting users, roles, and grants..."
    
    local acl_dir="${MIGRATION_DIR}/access_control"
    mkdir -p "$acl_dir"
    
    # Export user creation statements
    log "Exporting users..."
    local users
    users=$(ch_query "SELECT name FROM system.users WHERE name NOT IN ('default') FORMAT TSV" || echo "")
    
    > "${acl_dir}/users.sql"
    while IFS= read -r user; do
        [ -z "$user" ] && continue
        ch_query "SHOW CREATE USER \`${user}\`" >> "${acl_dir}/users.sql" 2>/dev/null || true
        echo ";" >> "${acl_dir}/users.sql"
    done <<< "$users"
    log "  Users exported: $(echo "$users" | grep -c . || echo "0")"
    
    # Export role creation statements
    log "Exporting roles..."
    local roles
    roles=$(ch_query "SELECT name FROM system.roles FORMAT TSV" || echo "")
    
    > "${acl_dir}/roles.sql"
    while IFS= read -r role; do
        [ -z "$role" ] && continue
        ch_query "SHOW CREATE ROLE \`${role}\`" >> "${acl_dir}/roles.sql" 2>/dev/null || true
        echo ";" >> "${acl_dir}/roles.sql"
    done <<< "$roles"
    log "  Roles exported: $(echo "$roles" | grep -c . || echo "0")"
    
    # Export grants
    log "Exporting grants..."
    > "${acl_dir}/grants.sql"
    while IFS= read -r user; do
        [ -z "$user" ] && continue
        ch_query "SHOW GRANTS FOR \`${user}\`" >> "${acl_dir}/grants.sql" 2>/dev/null || true
        echo ";" >> "${acl_dir}/grants.sql"
    done <<< "$users"
    log "  Grants exported"
    
    # Export row policies
    log "Exporting row policies..."
    ch_query "SELECT name, short_name, database, table FROM system.row_policies FORMAT TSV" > "${acl_dir}/row_policies.txt" 2>/dev/null || touch "${acl_dir}/row_policies.txt"
    
    # Export settings profiles
    log "Exporting settings profiles..."
    local profiles
    profiles=$(ch_query "SELECT name FROM system.settings_profiles FORMAT TSV" || echo "")
    
    > "${acl_dir}/profiles.sql"
    while IFS= read -r profile; do
        [ -z "$profile" ] && continue
        ch_query "SHOW CREATE SETTINGS PROFILE \`${profile}\`" >> "${acl_dir}/profiles.sql" 2>/dev/null || true
        echo ";" >> "${acl_dir}/profiles.sql"
    done <<< "$profiles"
    
    # Export quotas
    log "Exporting quotas..."
    local quotas
    quotas=$(ch_query "SELECT name FROM system.quotas FORMAT TSV" || echo "")
    
    > "${acl_dir}/quotas.sql"
    while IFS= read -r quota; do
        [ -z "$quota" ] && continue
        ch_query "SHOW CREATE QUOTA \`${quota}\`" >> "${acl_dir}/quotas.sql" 2>/dev/null || true
        echo ";" >> "${acl_dir}/quotas.sql"
    done <<< "$quotas"
    
    # Transfer to VPS B if host specified
    if [ -n "$VPS_B_HOST" ]; then
        log "Transferring access control files to VPS B..."
        ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${VPS_B_USER}@${VPS_B_HOST}" "mkdir -p '${acl_dir}'"
        scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${acl_dir}"/*.sql "${VPS_B_USER}@${VPS_B_HOST}:${acl_dir}/" 2>/dev/null || true
        scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${acl_dir}"/*.txt "${VPS_B_USER}@${VPS_B_HOST}:${acl_dir}/" 2>/dev/null || true
    fi
    
    success "Access control exported"
}

# ============================================================
# Command: Export all (dependency-ordered)
# ============================================================
export_all() {
    log "Starting full export of all objects..."
    
    if [ ! -f "${MIGRATION_DIR}/data-tables.txt" ]; then
        log "Object lists not found. Running assessment first..."
        assess
    fi
    
    # Export database creation statements
    log "Exporting database schemas..."
    local db_dir="${MIGRATION_DIR}/databases"
    mkdir -p "$db_dir"
    while IFS= read -r db; do
        [ -z "$db" ] && continue
        ch_query_raw "SHOW CREATE DATABASE \`${db}\`" > "${db_dir}/${db}.sql" 2>/dev/null || true
    done < "${MIGRATION_DIR}/databases.txt"
    
    if [ -n "$VPS_B_HOST" ]; then
        ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${VPS_B_USER}@${VPS_B_HOST}" "mkdir -p '${db_dir}'"
        scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${db_dir}"/*.sql "${VPS_B_USER}@${VPS_B_HOST}:${db_dir}/" 2>/dev/null || true
    fi
    
    # Phase 1: Data tables (must come first — MVs depend on them)
    local total_data=$(wc -l < "${MIGRATION_DIR}/data-tables.txt" | tr -d ' ')
    local current=0
    
    if [ "$total_data" -gt 0 ]; then
        log "=========================================="
        log "Phase 1: Exporting $total_data data tables"
        log "=========================================="
        
        while IFS= read -r table; do
            [ -z "$table" ] && continue
            current=$((current + 1))
            log "[$current/$total_data] Processing: $table"
            export_table "$table" || true
            sleep 3
        done < "${MIGRATION_DIR}/data-tables.txt"
    fi
    
    # Phase 2: Dictionaries
    local total_dicts=$(wc -l < "${MIGRATION_DIR}/dictionaries.txt" | tr -d ' ')
    current=0
    
    if [ "$total_dicts" -gt 0 ]; then
        log "=========================================="
        log "Phase 2: Exporting $total_dicts dictionaries"
        log "=========================================="
        
        while IFS= read -r table; do
            [ -z "$table" ] && continue
            current=$((current + 1))
            log "[$current/$total_dicts] Processing: $table"
            export_table "$table" || true
        done < "${MIGRATION_DIR}/dictionaries.txt"
    fi
    
    # Phase 3: Materialized Views (depend on base tables)
    local total_mvs=$(wc -l < "${MIGRATION_DIR}/materialized-views.txt" | tr -d ' ')
    current=0
    
    if [ "$total_mvs" -gt 0 ]; then
        log "=========================================="
        log "Phase 3: Exporting $total_mvs materialized views"
        log "=========================================="
        
        while IFS= read -r table; do
            [ -z "$table" ] && continue
            current=$((current + 1))
            log "[$current/$total_mvs] Processing: $table"
            export_table "$table" || true
        done < "${MIGRATION_DIR}/materialized-views.txt"
    fi
    
    # Phase 4: Views (depend on base tables and MVs)
    local total_views=$(wc -l < "${MIGRATION_DIR}/views.txt" | tr -d ' ')
    current=0
    
    if [ "$total_views" -gt 0 ]; then
        log "=========================================="
        log "Phase 4: Exporting $total_views views"
        log "=========================================="
        
        while IFS= read -r table; do
            [ -z "$table" ] && continue
            current=$((current + 1))
            log "[$current/$total_views] Processing: $table"
            export_table "$table" || true
        done < "${MIGRATION_DIR}/views.txt"
    fi
    
    # Phase 5: Access control (users, roles, grants)
    log "=========================================="
    log "Phase 5: Exporting access control"
    log "=========================================="
    export_access_control
    
    # Summary
    local total=$((total_data + total_dicts + total_mvs + total_views))
    log "=========================================="
    log "Migration Summary"
    log "=========================================="
    log "Total objects: $total"
    log "  Data tables:        $total_data"
    log "  Dictionaries:       $total_dicts"
    log "  Materialized Views: $total_mvs"
    log "  Views:              $total_views"
    log "Migrated: $(wc -l < "$MIGRATED_LOG" | tr -d ' ')"
    log "Failed:   $(wc -l < "$FAILED_LOG" | tr -d ' ')"
    
    if [ -s "$FAILED_LOG" ]; then
        warning "Some objects failed to migrate. Check $FAILED_LOG"
        log "To retry failed tables, run: $0 resume"
    fi
    
    success "Export complete! Run 'sudo $0 import' on VPS B to restore."
}

# ============================================================
# Command: Import (run on VPS B to restore everything)
# ============================================================
import_all() {
    log "Starting import on VPS B..."
    log "Migration directory: $MIGRATION_DIR"
    
    if [ ! -d "$MIGRATION_DIR" ]; then
        error "Migration directory not found: $MIGRATION_DIR"
        error "Make sure migration files have been transferred to this server."
        exit 1
    fi
    
    # Phase 1: Create databases
    log "=========================================="
    log "Phase 1: Creating databases"
    log "=========================================="
    local db_dir="${MIGRATION_DIR}/databases"
    if [ -d "$db_dir" ]; then
        for db_file in "$db_dir"/*.sql; do
            [ ! -f "$db_file" ] && continue
            local db_name
            db_name=$(basename "$db_file" .sql)
            log "Creating database: $db_name"
            ch_query_raw "$(cat "$db_file")" 2>&1 || warning "Failed to create database: $db_name (may already exist)"
        done
    else
        warning "No database schemas found in $db_dir"
    fi
    
    # Phase 2: Create data tables and import data
    log "=========================================="
    log "Phase 2: Creating tables and importing data"
    log "=========================================="
    
    if [ -f "${MIGRATION_DIR}/data-tables.txt" ]; then
        while IFS= read -r full_table; do
            [ -z "$full_table" ] && continue
            local database=${full_table%%.*}
            local table=${full_table#*.}
            local table_dir="${MIGRATION_DIR}/${database}/${table}"
            
            if [ ! -d "$table_dir" ]; then
                warning "No export directory for: $full_table"
                continue
            fi
            
            log "Processing: $full_table"
            
            # Ensure database exists
            ch_query_raw "CREATE DATABASE IF NOT EXISTS \`${database}\`" 2>/dev/null || true
            
            # Create table from schema
            if [ -f "${table_dir}/schema.sql" ]; then
                local schema
                schema=$(cat "${table_dir}/schema.sql")
                if ch_query_raw "$schema" 2>"${table_dir}/import_schema.error"; then
                    log "  Table created: $full_table"
                else
                    # Table might already exist
                    if ch_query "SELECT 1 FROM system.tables WHERE database='${database}' AND name='${table}'" > /dev/null 2>&1; then
                        log "  Table already exists: $full_table"
                    else
                        warning "  Failed to create table: $full_table"
                        cat "${table_dir}/import_schema.error" 2>/dev/null || true
                        continue
                    fi
                fi
            fi
            
            # Import data batches
            local batch_count=0
            for batch_file in "${table_dir}"/batch_*.native.gz; do
                [ ! -f "$batch_file" ] && continue
                batch_count=$((batch_count + 1))
                log "  Importing batch $batch_count..."
                if gzip -dc "$batch_file" | ch_query_raw "INSERT INTO ${full_table} FORMAT Native" 2>"${table_dir}/import_batch_${batch_count}.error"; then
                    log "  Batch $batch_count imported"
                else
                    error "  Failed to import batch $batch_count for $full_table"
                    cat "${table_dir}/import_batch_${batch_count}.error" 2>/dev/null || true
                fi
            done
            
            if [ "$batch_count" -eq 0 ]; then
                log "  No data batches (table may be empty)"
            fi
            
            # Verify row count
            local imported_rows
            imported_rows=$(ch_query "SELECT count() FROM ${full_table}" || echo "0")
            log "  Rows imported: $imported_rows"
            
        done < "${MIGRATION_DIR}/data-tables.txt"
    fi
    
    # Phase 3: Create dictionaries
    log "=========================================="
    log "Phase 3: Creating dictionaries"
    log "=========================================="
    if [ -f "${MIGRATION_DIR}/dictionaries.txt" ]; then
        while IFS= read -r full_table; do
            [ -z "$full_table" ] && continue
            local database=${full_table%%.*}
            local table=${full_table#*.}
            local table_dir="${MIGRATION_DIR}/${database}/${table}"
            
            if [ -f "${table_dir}/schema.sql" ]; then
                ch_query_raw "CREATE DATABASE IF NOT EXISTS \`${database}\`" 2>/dev/null || true
                log "Creating dictionary: $full_table"
                ch_query_raw "$(cat "${table_dir}/schema.sql")" 2>&1 || warning "Failed to create dictionary: $full_table"
            fi
        done < "${MIGRATION_DIR}/dictionaries.txt"
    fi
    
    # Phase 4: Create materialized views
    log "=========================================="
    log "Phase 4: Creating materialized views"
    log "=========================================="
    if [ -f "${MIGRATION_DIR}/materialized-views.txt" ]; then
        while IFS= read -r full_table; do
            [ -z "$full_table" ] && continue
            local database=${full_table%%.*}
            local table=${full_table#*.}
            local table_dir="${MIGRATION_DIR}/${database}/${table}"
            
            if [ -f "${table_dir}/schema.sql" ]; then
                ch_query_raw "CREATE DATABASE IF NOT EXISTS \`${database}\`" 2>/dev/null || true
                log "Creating materialized view: $full_table"
                ch_query_raw "$(cat "${table_dir}/schema.sql")" 2>&1 || warning "Failed to create MV: $full_table"
            fi
        done < "${MIGRATION_DIR}/materialized-views.txt"
    fi
    
    # Phase 5: Create views
    log "=========================================="
    log "Phase 5: Creating views"
    log "=========================================="
    if [ -f "${MIGRATION_DIR}/views.txt" ]; then
        while IFS= read -r full_table; do
            [ -z "$full_table" ] && continue
            local database=${full_table%%.*}
            local table=${full_table#*.}
            local table_dir="${MIGRATION_DIR}/${database}/${table}"
            
            if [ -f "${table_dir}/schema.sql" ]; then
                ch_query_raw "CREATE DATABASE IF NOT EXISTS \`${database}\`" 2>/dev/null || true
                log "Creating view: $full_table"
                ch_query_raw "$(cat "${table_dir}/schema.sql")" 2>&1 || warning "Failed to create view: $full_table"
            fi
        done < "${MIGRATION_DIR}/views.txt"
    fi
    
    # Phase 6: Restore access control
    log "=========================================="
    log "Phase 6: Restoring access control"
    log "=========================================="
    local acl_dir="${MIGRATION_DIR}/access_control"
    if [ -d "$acl_dir" ]; then
        # Restore roles first (users may reference roles)
        if [ -f "${acl_dir}/roles.sql" ] && [ -s "${acl_dir}/roles.sql" ]; then
            log "Restoring roles..."
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                [[ "$line" == ";" ]] && continue
                ch_query_raw "$line" 2>/dev/null || true
            done < "${acl_dir}/roles.sql"
        fi
        
        # Restore settings profiles
        if [ -f "${acl_dir}/profiles.sql" ] && [ -s "${acl_dir}/profiles.sql" ]; then
            log "Restoring settings profiles..."
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                [[ "$line" == ";" ]] && continue
                ch_query_raw "$line" 2>/dev/null || true
            done < "${acl_dir}/profiles.sql"
        fi
        
        # Restore quotas
        if [ -f "${acl_dir}/quotas.sql" ] && [ -s "${acl_dir}/quotas.sql" ]; then
            log "Restoring quotas..."
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                [[ "$line" == ";" ]] && continue
                ch_query_raw "$line" 2>/dev/null || true
            done < "${acl_dir}/quotas.sql"
        fi
        
        # Restore users
        if [ -f "${acl_dir}/users.sql" ] && [ -s "${acl_dir}/users.sql" ]; then
            log "Restoring users..."
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                [[ "$line" == ";" ]] && continue
                ch_query_raw "$line" 2>/dev/null || true
            done < "${acl_dir}/users.sql"
        fi
        
        # Restore grants
        if [ -f "${acl_dir}/grants.sql" ] && [ -s "${acl_dir}/grants.sql" ]; then
            log "Restoring grants..."
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                [[ "$line" == ";" ]] && continue
                ch_query_raw "$line" 2>/dev/null || true
            done < "${acl_dir}/grants.sql"
        fi
        
        success "Access control restored"
    else
        warning "No access control data found"
    fi
    
    success "Import complete!"
    log ""
    log "Next steps:"
    log "  1. Run: sudo $0 verify --host VPS_A_IP  (to compare row counts)"
    log "  2. Test your application queries"
    log "  3. Update application connection strings to point to this server"
}

# ============================================================
# Command: Direct file copy
# ============================================================
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

# ============================================================
# Command: Verify migration
# ============================================================
verify_migration() {
    log "Verifying migration on VPS B..."
    
    if [ -z "$VPS_B_HOST" ]; then
        error "VPS B host is required for verify command"
        exit 1
    fi
    
    # Get row counts from both servers
    log "Getting row counts from VPS A (local)..."
    ch_query "SELECT 
        concat(database, '.', table) as tbl,
        sum(rows) as rows
    FROM system.parts 
    WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') 
    AND active
    GROUP BY database, table
    ORDER BY tbl
    FORMAT TSV" > "${MIGRATION_DIR}/vps-a-counts.txt" 2>/dev/null || error "Cannot connect to VPS A"
    
    log "Getting row counts from VPS B..."
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${VPS_B_USER}@${VPS_B_HOST}" \
        "clickhouse-client --secure --port 9440 -q \"SELECT 
            concat(database, '.', table) as tbl,
            sum(rows) as rows
        FROM system.parts 
        WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') 
        AND active
        GROUP BY database, table
        ORDER BY tbl
        FORMAT TSV\"" > "${MIGRATION_DIR}/vps-b-counts.txt" 2>/dev/null || error "Cannot connect to VPS B"
    
    # Compare objects
    log "Getting object counts from VPS B..."
    local vps_b_tables
    vps_b_tables=$(ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${VPS_B_USER}@${VPS_B_HOST}" \
        "clickhouse-client --secure --port 9440 -q \"SELECT engine, count() FROM system.tables WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') GROUP BY engine FORMAT TSV\"" 2>/dev/null || echo "")
    
    log "=========================================="
    log "Verification Results"
    log "=========================================="
    
    echo ""
    echo "--- Object counts on VPS B ---"
    echo "$vps_b_tables" | column -t
    echo ""
    
    echo "--- Row count comparison ---"
    echo "Tables with mismatched row counts:"
    comm -3 <(sort "${MIGRATION_DIR}/vps-a-counts.txt") <(sort "${MIGRATION_DIR}/vps-b-counts.txt") | tee "${MIGRATION_DIR}/mismatched.txt"
    
    if [ ! -s "${MIGRATION_DIR}/mismatched.txt" ]; then
        success "All data tables verified — row counts match!"
    else
        warning "Some tables have mismatched row counts. Review ${MIGRATION_DIR}/mismatched.txt"
    fi
    
    # Check users on VPS B
    log "Checking users on VPS B..."
    ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no "${VPS_B_USER}@${VPS_B_HOST}" \
        "clickhouse-client --secure --port 9440 -q \"SELECT name FROM system.users FORMAT TSV\"" 2>/dev/null || echo "(unable to query users)"
}

# ============================================================
# Command: Resume failed migrations
# ============================================================
resume_failed() {
    log "Resuming failed migrations..."
    
    if [ ! -s "$FAILED_LOG" ]; then
        success "No failed migrations to resume"
        return 0
    fi
    
    log "Retrying $(wc -l < "$FAILED_LOG" | tr -d ' ') failed tables with smaller batches..."
    BATCH_SIZE=10000  # Smaller batch for retry
    
    # Make a copy so we can clear the log
    cp "$FAILED_LOG" "${FAILED_LOG}.retry"
    > "$FAILED_LOG"
    
    while IFS= read -r table; do
        if [ -n "$table" ]; then
            log "Retrying: $table"
            export_table "$table" || true
        fi
    done < "${FAILED_LOG}.retry"
    
    rm -f "${FAILED_LOG}.retry"
}

# ============================================================
# Main
# ============================================================
main() {
    case "${COMMAND:-}" in
        assess)
            assess
            ;;
        export)
            if [ -z "$TABLE_ARG" ]; then
                error "Table name required. Usage: $0 export <database.table>"
                usage
                exit 1
            fi
            export_table "$TABLE_ARG"
            ;;
        export-all)
            export_all
            ;;
        import)
            import_all
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
