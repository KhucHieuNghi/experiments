#!/bin/bash

# ClickHouse Restore Script for VPS B (Destination Server)
# Description: Restores ClickHouse backup from VPS A to VPS B
# Author: ClickHouse Testing Project
# Version: 1.0.0

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
BACKUP_PATH=""
SOURCE_HOST=""
TEMP_DIR="/tmp/clickhouse-restore"
LOG_FILE=""
VERIFY_RESTORE=true
SKIP_EXISTING=false
MAX_THREADS=4
RESTORE_FORMAT="Native"

# ClickHouse connection settings
CLICKHOUSE_HOST="localhost"
CLICKHOUSE_PORT="9440"
CLICKHOUSE_USER="default"
CLICKHOUSE_PASSWORD=""
CLICKHOUSE_SECURE="true"

# Logging functions
log() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}${msg}${NC}"
    [[ -n "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    local msg="[ERROR] $1"
    echo -e "${RED}${msg}${NC}" >&2
    [[ -n "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

success() {
    local msg="[SUCCESS] $1"
    echo -e "${GREEN}${msg}${NC}"
    [[ -n "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

warning() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}"
    [[ -n "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Show usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

ClickHouse Restore Script for VPS B

OPTIONS:
    -h, --help              Show this help message
    -s, --source HOST       Source VPS hostname or IP (VPS A)
    -p, --backup-path PATH  Path to backup on source or local backup file/directory
    -t, --threads NUM       Number of parallel threads (default: ${MAX_THREADS})
    --host HOST            ClickHouse host (default: ${CLICKHOUSE_HOST})
    --port PORT            ClickHouse port (default: ${CLICKHOUSE_PORT})
    --user USER            ClickHouse user (default: ${CLICKHOUSE_USER})
    --password PASS        ClickHouse password
    --secure               Use secure connection (TLS)
    --skip-existing        Skip tables that already exist
    --no-verify            Skip verification after restore
    --dry-run              Show what would be restored without executing

EXAMPLES:
    # Restore from local backup
    sudo $0 -p /backup/clickhouse/clickhouse-backup-20240115_120000.tar.gz

    # Restore from remote VPS A
    sudo $0 -s vps-a.example.com -p /backup/clickhouse/

    # Restore with authentication
    sudo $0 -p /backup/clickhouse/backup.tar.gz --user admin --password secret123

    # Dry run to see what would be restored
    sudo $0 -p /backup/clickhouse/backup.tar.gz --dry-run

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -s|--source)
                SOURCE_HOST="$2"
                shift 2
                ;;
            -p|--backup-path)
                BACKUP_PATH="$2"
                shift 2
                ;;
            -t|--threads)
                MAX_THREADS="$2"
                shift 2
                ;;
            --host)
                CLICKHOUSE_HOST="$2"
                shift 2
                ;;
            --port)
                CLICKHOUSE_PORT="$2"
                shift 2
                ;;
            --user)
                CLICKHOUSE_USER="$2"
                shift 2
                ;;
            --password)
                CLICKHOUSE_PASSWORD="$2"
                shift 2
                ;;
            --secure)
                CLICKHOUSE_SECURE="true"
                shift
                ;;
            --skip-existing)
                SKIP_EXISTING=true
                shift
                ;;
            --no-verify)
                VERIFY_RESTORE=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$BACKUP_PATH" ]]; then
        error "Backup path is required. Use -p or --backup-path"
        usage
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if ClickHouse is installed
    if ! command -v clickhouse-client &> /dev/null; then
        error "clickhouse-client not found. Is ClickHouse installed?"
        exit 1
    fi
    
    # Check if ClickHouse server is running
    if [[ "$DRY_RUN" != "true" ]]; then
        if ! clickhouse-client --host "$CLICKHOUSE_HOST" --port "$CLICKHOUSE_PORT" \
            ${CLICKHOUSE_USER:+--user "$CLICKHOUSE_USER"} \
            ${CLICKHOUSE_PASSWORD:+--password "$CLICKHOUSE_PASSWORD"} \
            ${CLICKHOUSE_SECURE:+--secure} \
            -q "SELECT 1" 2>/dev/null; then
            error "Cannot connect to ClickHouse server at ${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}"
            exit 1
        fi
    fi
    
    # Create temporary directory
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$TEMP_DIR"
        LOG_FILE="${TEMP_DIR}/restore.log"
        touch "$LOG_FILE"
    fi
    
    success "Prerequisites check passed"
}

# Build clickhouse-client command
build_client_cmd() {
    local cmd="clickhouse-client --host $CLICKHOUSE_HOST --port $CLICKHOUSE_PORT"
    
    if [[ -n "$CLICKHOUSE_USER" ]]; then
        cmd="$cmd --user \"$CLICKHOUSE_USER\""
    fi
    
    if [[ -n "$CLICKHOUSE_PASSWORD" ]]; then
        cmd="$cmd --password \"$CLICKHOUSE_PASSWORD\""
    fi
    
    if [[ "$CLICKHOUSE_SECURE" == "true" ]]; then
        cmd="$cmd --secure"
    fi
    
    echo "$cmd"
}

# Transfer backup from source
transfer_backup() {
    if [[ -z "$SOURCE_HOST" ]]; then
        log "Using local backup at: $BACKUP_PATH"
        return
    fi
    
    log "Transferring backup from ${SOURCE_HOST}..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would transfer backup from ${SOURCE_HOST}:${BACKUP_PATH}"
        return
    fi
    
    # Check SSH connectivity
    if ! ssh -o ConnectTimeout=5 "${SOURCE_HOST}" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        error "Cannot connect to source host via SSH: ${SOURCE_HOST}"
        error "Please ensure SSH key authentication is configured"
        exit 1
    fi
    
    # Find latest backup on source
    local remote_backup=$(ssh "${SOURCE_HOST}" "ls -t ${BACKUP_PATH}/clickhouse-backup-*.tar.gz 2>/dev/null | head -1")
    
    if [[ -z "$remote_backup" ]]; then
        error "No backup found on ${SOURCE_HOST} at ${BACKUP_PATH}"
        exit 1
    fi
    
    log "Found backup: ${remote_backup}"
    
    # Transfer backup
    local backup_filename=$(basename "$remote_backup")
    local local_backup="${TEMP_DIR}/${backup_filename}"
    
    log "Transferring ${backup_filename}..."
    scp "${SOURCE_HOST}:${remote_backup}" "$local_backup" || {
        error "Failed to transfer backup from source"
        exit 1
    }
    
    BACKUP_PATH="$local_backup"
    success "Backup transferred to: $BACKUP_PATH"
}

# Extract backup
extract_backup() {
    log "Extracting backup..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would extract backup"
        return
    fi
    
    # Determine if backup is compressed
    if [[ -f "$BACKUP_PATH" ]]; then
        # Compressed file
        case "$BACKUP_PATH" in
            *.tar.gz|*.tgz)
                tar -xzf "$BACKUP_PATH" -C "$TEMP_DIR" || {
                    error "Failed to extract tar.gz backup"
                    exit 1
                }
                ;;
            *.tar.bz2)
                tar -xjf "$BACKUP_PATH" -C "$TEMP_DIR" || {
                    error "Failed to extract tar.bz2 backup"
                    exit 1
                }
                ;;
            *.tar)
                tar -xf "$BACKUP_PATH" -C "$TEMP_DIR" || {
                    error "Failed to extract tar backup"
                    exit 1
                }
                ;;
            *.zip)
                unzip -q "$BACKUP_PATH" -d "$TEMP_DIR" || {
                    error "Failed to extract zip backup"
                    exit 1
                }
                ;;
            *)
                error "Unknown backup format: $BACKUP_PATH"
                exit 1
                ;;
        esac
        
        # Find extracted directory
        BACKUP_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "20*" | head -1)
        
        if [[ -z "$BACKUP_DIR" ]]; then
            error "Could not find extracted backup directory"
            exit 1
        fi
    elif [[ -d "$BACKUP_PATH" ]]; then
        # Directory backup
        BACKUP_DIR="$BACKUP_PATH"
    else
        error "Backup path does not exist: $BACKUP_PATH"
        exit 1
    fi
    
    success "Backup extracted to: $BACKUP_DIR"
    
    # Load manifest if exists
    if [[ -f "${BACKUP_DIR}/MANIFEST.json" ]]; then
        log "Backup manifest found"
        log "  Created: $(grep '"timestamp"' "${BACKUP_DIR}/MANIFEST.json" | cut -d'"' -f4)"
        log "  Format: $(grep '"backup_format"' "${BACKUP_DIR}/MANIFEST.json" | cut -d'"' -f4)"
        RESTORE_FORMAT=$(grep '"backup_format"' "${BACKUP_DIR}/MANIFEST.json" | cut -d'"' -f4)
    fi
}

# Pre-restore validation
validate_backup() {
    log "Validating backup..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would validate backup"
        return
    fi
    
    # Check required directories exist
    local required_dirs=("schemas" "data")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${BACKUP_DIR}/${dir}" ]]; then
            warning "Required directory missing: ${dir}"
        fi
    done
    
    # Check disk space
    local backup_size=$(du -sm "$BACKUP_DIR" | cut -f1)
    local available_space=$(df -m /var/lib/clickhouse | awk 'NR==2 {print $4}')
    local required_space=$((backup_size * 2))  # Double for safety
    
    if [[ "$available_space" -lt "$required_space" ]]; then
        error "Insufficient disk space. Required: ${required_space}MB, Available: ${available_space}MB"
        exit 1
    fi
    
    success "Backup validation passed"
}

# Restore database schemas
restore_schemas() {
    log "Restoring database schemas..."
    
    local client_cmd=$(build_client_cmd)
    local schemas_dir="${BACKUP_DIR}/schemas"
    
    if [[ ! -d "$schemas_dir" ]]; then
        warning "Schemas directory not found: $schemas_dir"
        return
    fi
    
    # Restore databases
    if [[ -f "${schemas_dir}/databases.sql" ]]; then
        log "Creating databases..."
        
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^--.*$ ]] && continue
            [[ -z "$line" ]] && continue
            
            if [[ "$line" =~ ^CREATE[[:space:]]+DATABASE ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "  [DRY-RUN] Would execute: $line"
                else
                    log "  Creating database: $(echo "$line" | grep -oE 'DATABASE[[:space:]]+[^[:space:]]+' | awk '{print $2}')"
                    eval "$client_cmd -q \"$line\"" 2>&1 || {
                        warning "Failed to create database: $line"
                    }
                fi
            fi
        done < "${schemas_dir}/databases.sql"
    fi
    
    # Restore tables
    for db_dir in "$schemas_dir"/*/; do
        [[ ! -d "$db_dir" ]] && continue
        
        local db_name=$(basename "$db_dir")
        log "Restoring tables for database: $db_name"
        
        for table_file in "$db_dir"/*.sql; do
            [[ ! -f "$table_file" ]] && continue
            
            local table_name=$(basename "$table_file" .sql)
            
            # Check if table already exists
            local table_exists=$(eval "$client_cmd -q \"SELECT count() FROM system.tables WHERE database = '${db_name}' AND name = '${table_name}'\"" 2>/dev/null || echo "0")
            
            if [[ "$table_exists" -gt 0 ]]; then
                if [[ "$SKIP_EXISTING" == "true" ]]; then
                    log "  Skipping existing table: ${db_name}.${table_name}"
                    continue
                else
                    warning "Table already exists: ${db_name}.${table_name}"
                    read -p "  Drop and recreate? (y/N): " drop_table
                    if [[ ! "$drop_table" =~ ^[Yy]$ ]]; then
                        continue
                    fi
                    eval "$client_cmd -q \"DROP TABLE IF EXISTS ${db_name}.${table_name}\"" 2>&1 || true
                fi
            fi
            
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "  [DRY-RUN] Would create table: ${db_name}.${table_name}"
            else
                log "  Creating table: ${db_name}.${table_name}"
                local create_stmt=$(cat "$table_file")
                eval "$client_cmd -q \"$create_stmt\"" 2>&1 || {
                    warning "Failed to create table: ${db_name}.${table_name}"
                    continue
                }
            fi
        done
    done
    
    success "Database schemas restored"
}

# Restore table data
restore_data() {
    log "Restoring table data..."
    
    local client_cmd=$(build_client_cmd)
    local data_dir="${BACKUP_DIR}/data"
    
    if [[ ! -d "$data_dir" ]]; then
        warning "Data directory not found: $data_dir"
        return
    fi
    
    # Process each database
    for db_dir in "$data_dir"/*/; do
        [[ ! -d "$db_dir" ]] && continue
        
        local db_name=$(basename "$db_dir")
        log "Restoring data for database: $db_name"
        
        # Process each table
        for data_file in "$db_dir"/*; do
            [[ ! -f "$data_file" ]] && continue
            
            local filename=$(basename "$data_file")
            local table_name=""
            local file_format=""
            local compressed=false
            
            # Parse filename
            if [[ "$filename" =~ \.gz$ ]]; then
                compressed=true
                filename="${filename%.gz}"
            fi
            
            if [[ "$filename" =~ \.bin$ ]]; then
                table_name="${filename%.bin}"
                file_format="Native"
            elif [[ "$filename" =~ \.tsv$ ]]; then
                table_name="${filename%.tsv}"
                file_format="TabSeparated"
            elif [[ "$filename" =~ \.parquet$ ]]; then
                table_name="${filename%.parquet}"
                file_format="Parquet"
            else
                warning "Unknown file format: $filename"
                continue
            fi
            
            # Check if table exists
            local table_exists=$(eval "$client_cmd -q \"SELECT count() FROM system.tables WHERE database = '${db_name}' AND name = '${table_name}'\"" 2>/dev/null || echo "0")
            
            if [[ "$table_exists" -eq 0 ]]; then
                warning "Table does not exist: ${db_name}.${table_name}"
                continue
            fi
            
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "  [DRY-RUN] Would import data to: ${db_name}.${table_name}"
                continue
            fi
            
            log "  Importing data: ${db_name}.${table_name}"
            
            # Prepare input
            local input_cmd="cat"
            if [[ "$compressed" == "true" ]]; then
                input_cmd="gzip -dc"
            fi
            
            # Import data
            $input_cmd "$data_file" | eval "$client_cmd -q \"INSERT INTO ${db_name}.${table_name} FORMAT ${file_format}\" --max_insert_threads=${MAX_THREADS}" 2>&1 || {
                warning "Failed to import data to: ${db_name}.${table_name}"
                continue
            }
            
            # Get row count
            local row_count=$(eval "$client_cmd -q \"SELECT count() FROM ${db_name}.${table_name}\"" 2>/dev/null || echo "0")
            log "    Imported: ${row_count} rows"
            
        done
    done
    
    success "Table data restored"
}

# Restore users and permissions
restore_users() {
    log "Restoring users and permissions..."
    
    local client_cmd=$(build_client_cmd)
    local users_dir="${BACKUP_DIR}/users"
    
    if [[ ! -d "$users_dir" ]]; then
        warning "Users directory not found: $users_dir"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would restore users and permissions"
        return
    fi
    
    # Note: User restoration requires careful handling
    # For now, we'll just log the available user information
    log "Users backup available at: $users_dir"
    log "  - users.tsv: User definitions"
    log "  - grants.tsv: User grants"
    log "  - roles.tsv: Role definitions"
    log "  - quotas.tsv: Quota definitions"
    log "  - settings_profiles.tsv: Settings profiles"
    
    warning "User restoration requires manual review for security"
    log "Please review user files and create users manually if needed"
}

# Verify restore
verify_restore() {
    if [[ "$VERIFY_RESTORE" != "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    
    log "Verifying restore..."
    
    local client_cmd=$(build_client_cmd)
    
    # Check databases
    log "  Checking databases..."
    local db_count=$(eval "$client_cmd -q \"SELECT count() FROM system.databases WHERE name NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')\"" 2>/dev/null || echo "0")
    log "    Databases: $db_count"
    
    # Check tables
    log "  Checking tables..."
    local table_count=$(eval "$client_cmd -q \"SELECT count() FROM system.tables WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')\"" 2>/dev/null || echo "0")
    log "    Tables: $table_count"
    
    # Check total rows
    log "  Checking total rows..."
    local total_rows=$(eval "$client_cmd -q \"SELECT sum(total_rows) FROM system.parts WHERE active = 1 AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')\"" 2>/dev/null || echo "0")
    log "    Total rows: $total_rows"
    
    # Check disk usage
    log "  Checking disk usage..."
    local disk_usage=$(eval "$client_cmd -q \"SELECT formatReadableSize(sum(bytes_on_disk)) FROM system.parts WHERE active = 1 AND database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')\"" 2>/dev/null || echo "0")
    log "    Disk usage: $disk_usage"
    
    success "Restore verification complete"
}

# Cleanup temporary files
cleanup() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    
    log "Cleaning up temporary files..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log "  Removed: $TEMP_DIR"
    fi
}

# Display summary
display_summary() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "=========================================="
        echo -e "${YELLOW}DRY RUN COMPLETE${NC}"
        echo "=========================================="
        echo ""
        echo "No actual restore was performed."
        echo "Review the output above to see what would be restored."
        echo ""
        return
    fi
    
    echo ""
    echo "=========================================="
    echo -e "${GREEN}RESTORE COMPLETE${NC}"
    echo "=========================================="
    echo ""
    echo "Source: ${SOURCE_HOST:-Local}"
    echo "Backup: $BACKUP_PATH"
    echo ""
    
    local client_cmd=$(build_client_cmd)
    echo "Restored databases:"
    eval "$client_cmd -q \"SELECT name FROM system.databases WHERE name NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') ORDER BY name\"" 2>/dev/null || echo "  (Unable to query)"
    echo ""
    
    echo "Next steps:"
    echo "1. Verify data integrity"
    echo "2. Update application connection strings"
    echo "3. Configure monitoring"
    echo "4. Set up regular backups"
    echo ""
}

# Main function
main() {
    log "Starting ClickHouse restore process..."
    
    check_root
    parse_arguments "$@"
    check_prerequisites
    transfer_backup
    extract_backup
    validate_backup
    restore_schemas
    restore_data
    restore_users
    verify_restore
    cleanup
    display_summary
}

# Handle script interruption
trap 'error "Restore interrupted"; cleanup; exit 1' INT TERM

# Run main function
main "$@"
