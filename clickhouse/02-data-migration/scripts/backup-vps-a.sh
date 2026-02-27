#!/bin/bash

# ClickHouse Backup Script for VPS A (Source Server)
# Description: Creates comprehensive backup of ClickHouse databases, tables, and metadata
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
BACKUP_ROOT="/backup/clickhouse"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
LOG_FILE="${BACKUP_DIR}/backup.log"
CONFIG_BACKUP=true
COMPRESS_BACKUP=true
BACKUP_FORMAT="Native"  # Native, TSV, Parquet
MAX_THREADS=4
REMOVE_OLD_BACKUPS=true
KEEP_BACKUPS_DAYS=7

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
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    local msg="[ERROR] $1"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

success() {
    local msg="[SUCCESS] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

warning() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
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

ClickHouse Backup Script for VPS A

OPTIONS:
    -h, --help              Show this help message
    -d, --directory DIR     Backup directory (default: ${BACKUP_ROOT})
    -f, --format FORMAT     Backup format: Native, TSV, Parquet (default: ${BACKUP_FORMAT})
    -t, --threads NUM       Number of parallel threads (default: ${MAX_THREADS})
    --host HOST            ClickHouse host (default: ${CLICKHOUSE_HOST})
    --port PORT            ClickHouse port (default: ${CLICKHOUSE_PORT})
    --user USER            ClickHouse user (default: ${CLICKHOUSE_USER})
    --password PASS        ClickHouse password
    --secure               Use secure connection (TLS)
    --no-config            Skip configuration backup
    --no-compress          Don't compress backup
    --keep-days DAYS       Keep backups for N days (default: ${KEEP_BACKUPS_DAYS})
    --dry-run              Show what would be backed up without executing

EXAMPLES:
    # Basic backup
    sudo $0

    # Backup with specific directory and format
    sudo $0 -d /mnt/backup -f Parquet

    # Backup with authentication
    sudo $0 --user admin --password secret123

    # Dry run to see what would be backed up
    sudo $0 --dry-run

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
            -d|--directory)
                BACKUP_ROOT="$2"
                shift 2
                ;;
            -f|--format)
                BACKUP_FORMAT="$2"
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
            --no-config)
                CONFIG_BACKUP=false
                shift
                ;;
            --no-compress)
                COMPRESS_BACKUP=false
                shift
                ;;
            --keep-days)
                KEEP_BACKUPS_DAYS="$2"
                shift 2
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
    
    # Check available disk space (need at least 10GB)
    local available_space=$(df -BG "$BACKUP_ROOT" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G' || echo "0")
    if [[ "$available_space" -lt 10 ]]; then
        error "Insufficient disk space. At least 10GB required, found ${available_space}GB"
        exit 1
    fi
    
    # Create backup directory
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$BACKUP_DIR"/{schemas,data,users,metadata,config}
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

# Get list of databases
get_databases() {
    local client_cmd=$(build_client_cmd)
    eval "$client_cmd -q \"SELECT name FROM system.databases WHERE name NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') ORDER BY name\""
}

# Get list of tables for a database
get_tables() {
    local db=$1
    local client_cmd=$(build_client_cmd)
    eval "$client_cmd -q \"SELECT database, name, engine FROM system.tables WHERE database = '${db}' AND engine NOT IN ('View', 'MaterializedView', 'Dictionary') ORDER BY name\""
}

# Backup database schemas
backup_schemas() {
    log "Backing up database schemas..."
    
    local client_cmd=$(build_client_cmd)
    local databases=$(get_databases)
    
    # Backup CREATE DATABASE statements
    echo "-- Database creation statements" > "${BACKUP_DIR}/schemas/databases.sql"
    echo "-- Generated: $(date)" >> "${BACKUP_DIR}/schemas/databases.sql"
    echo "" >> "${BACKUP_DIR}/schemas/databases.sql"
    
    for db in $databases; do
        log "  Processing database: $db"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  [DRY-RUN] Would backup database: $db"
            continue
        fi
        
        # Get CREATE DATABASE statement
        eval "$client_cmd -q \"SHOW CREATE DATABASE ${db}\"" >> "${BACKUP_DIR}/schemas/databases.sql" 2>&1 || {
            warning "Failed to get schema for database: $db"
            continue
        }
        echo "" >> "${BACKUP_DIR}/schemas/databases.sql"
        
        # Create directory for tables
        mkdir -p "${BACKUP_DIR}/schemas/${db}"
        
        # Backup tables
        local tables=$(get_tables "$db")
        while IFS=$'\t' read -r table_db table_name engine; do
            [[ -z "$table_name" ]] && continue
            
            log "    Processing table: ${db}.${table_name} (engine: ${engine})"
            
            # Get CREATE TABLE statement
            eval "$client_cmd -q \"SHOW CREATE TABLE ${db}.${table_name}\"" > "${BACKUP_DIR}/schemas/${db}/${table_name}.sql" 2>&1 || {
                warning "Failed to get schema for table: ${db}.${table_name}"
                continue
            }
        done <<< "$tables"
    done
    
    success "Database schemas backed up"
}

# Backup table data
backup_data() {
    log "Backing up table data..."
    
    local client_cmd=$(build_client_cmd)
    local databases=$(get_databases)
    
    for db in $databases; do
        local tables=$(get_tables "$db")
        
        while IFS=$'\t' read -r table_db table_name engine; do
            [[ -z "$table_name" ]] && continue
            
            # Skip system tables
            [[ "$db" == "system" ]] && continue
            
            log "  Backing up data: ${db}.${table_name}"
            
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "  [DRY-RUN] Would backup table data: ${db}.${table_name}"
                continue
            fi
            
            # Create directory for data
            mkdir -p "${BACKUP_DIR}/data/${db}"
            
            # Determine file extension based on format
            local extension="bin"
            case "$BACKUP_FORMAT" in
                TSV) extension="tsv" ;;
                Parquet) extension="parquet" ;;
                *) extension="bin" ;;
            esac
            
            # Export data
            local output_file="${BACKUP_DIR}/data/${db}/${table_name}.${extension}"
            
            eval "$client_cmd -q \"SELECT * FROM ${db}.${table_name}\" --format $BACKUP_FORMAT > \"$output_file\"" 2>&1 || {
                warning "Failed to backup data for table: ${db}.${table_name}"
                rm -f "$output_file"
                continue
            }
            
            # Compress if enabled
            if [[ "$COMPRESS_BACKUP" == "true" ]] && [[ "$BACKUP_FORMAT" != "Parquet" ]]; then
                gzip "$output_file" && mv "${output_file}.gz" "$output_file.gz"
                output_file="${output_file}.gz"
            fi
            
            # Get row count
            local row_count=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
            log "    Exported: ${db}.${table_name} (${row_count} bytes)"
            
        done <<< "$tables"
    done
    
    success "Table data backed up"
}

# Backup users and permissions
backup_users() {
    log "Backing up users and permissions..."
    
    local client_cmd=$(build_client_cmd)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would backup users and permissions"
        return
    fi
    
    # Backup users
    eval "$client_cmd -q \"SELECT * FROM system.users FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/users/users.tsv" 2>&1 || {
        warning "Failed to backup users"
    }
    
    # Backup grants
    eval "$client_cmd -q \"SELECT * FROM system.grants FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/users/grants.tsv" 2>&1 || {
        warning "Failed to backup grants"
    }
    
    # Backup roles
    eval "$client_cmd -q \"SELECT * FROM system.roles FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/users/roles.tsv" 2>&1 || {
        warning "Failed to backup roles"
    }
    
    # Backup quotas
    eval "$client_cmd -q \"SELECT * FROM system.quotas FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/users/quotas.tsv" 2>&1 || {
        warning "Failed to backup quotas"
    }
    
    # Backup settings profiles
    eval "$client_cmd -q \"SELECT * FROM system.settings_profiles FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/users/settings_profiles.tsv" 2>&1 || {
        warning "Failed to backup settings profiles"
    }
    
    # Generate SQL scripts for recreation
    eval "$client_cmd -q \"SHOW USERS\"" > "${BACKUP_DIR}/users/user_list.txt" 2>&1 || true
    
    success "Users and permissions backed up"
}

# Backup metadata
backup_metadata() {
    log "Backing up metadata..."
    
    local client_cmd=$(build_client_cmd)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would backup metadata"
        return
    fi
    
    # Backup merge tree settings
    eval "$client_cmd -q \"SELECT * FROM system.merge_tree_settings FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/metadata/merge_tree_settings.tsv" 2>&1 || true
    
    # Backup parts
    eval "$client_cmd -q \"SELECT * FROM system.parts WHERE active = 1 FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/metadata/parts.tsv" 2>&1 || true
    
    # Backup mutations
    eval "$client_cmd -q \"SELECT * FROM system.mutations FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/metadata/mutations.tsv" 2>&1 || true
    
    # Backup dictionaries
    eval "$client_cmd -q \"SELECT * FROM system.dictionaries FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/metadata/dictionaries.tsv" 2>&1 || true
    
    # Backup functions
    eval "$client_cmd -q \"SELECT * FROM system.functions FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/metadata/functions.tsv" 2>&1 || true
    
    # Backup current processes
    eval "$client_cmd -q \"SELECT * FROM system.processes FORMAT TSVWithNamesAndTypes\"" > "${BACKUP_DIR}/metadata/processes.tsv" 2>&1 || true
    
    success "Metadata backed up"
}

# Backup configuration files
backup_config() {
    if [[ "$CONFIG_BACKUP" != "true" ]]; then
        log "Skipping configuration backup"
        return
    fi
    
    log "Backing up configuration files..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would backup configuration files"
        return
    fi
    
    # Backup main configuration
    if [[ -f /etc/clickhouse-server/config.xml ]]; then
        cp /etc/clickhouse-server/config.xml "${BACKUP_DIR}/config/config.xml"
        log "  Backed up config.xml"
    fi
    
    # Backup users configuration
    if [[ -f /etc/clickhouse-server/users.xml ]]; then
        cp /etc/clickhouse-server/users.xml "${BACKUP_DIR}/config/users.xml"
        log "  Backed up users.xml"
    fi
    
    # Backup additional config files
    if [[ -d /etc/clickhouse-server/conf.d ]]; then
        cp -r /etc/clickhouse-server/conf.d "${BACKUP_DIR}/config/"
        log "  Backed up conf.d/"
    fi
    
    if [[ -d /etc/clickhouse-server/users.d ]]; then
        cp -r /etc/clickhouse-server/users.d "${BACKUP_DIR}/config/"
        log "  Backed up users.d/"
    fi
    
    # Backup custom configuration files
    if [[ -d /etc/clickhouse-server/config.d ]]; then
        cp -r /etc/clickhouse-server/config.d "${BACKUP_DIR}/config/"
        log "  Backed up config.d/"
    fi
    
    success "Configuration files backed up"
}

# Create backup manifest
create_manifest() {
    log "Creating backup manifest..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    
    local manifest_file="${BACKUP_DIR}/MANIFEST.json"
    
    cat > "$manifest_file" << EOF
{
    "backup_info": {
        "version": "1.0.0",
        "timestamp": "${TIMESTAMP}",
        "hostname": "$(hostname)",
        "clickhouse_version": "$(clickhouse-client --version 2>&1 | head -1 | awk '{print $3}')",
        "backup_format": "${BACKUP_FORMAT}",
        "compressed": ${COMPRESS_BACKUP}
    },
    "databases": [
$(get_databases | awk '{printf "        \"%s\"", $0; if(NR>1) printf ","; printf "\n"}')
    ],
    "configuration": {
        "backup_directory": "${BACKUP_DIR}",
        "max_threads": ${MAX_THREADS},
        "include_config": ${CONFIG_BACKUP}
    },
    "statistics": {
        "total_size": "$(du -sh "$BACKUP_DIR" | cut -f1)",
        "file_count": $(find "$BACKUP_DIR" -type f | wc -l)
    }
}
EOF
    
    success "Backup manifest created"
}

# Compress backup
compress_backup() {
    if [[ "$COMPRESS_BACKUP" != "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    
    log "Compressing backup..."
    
    local compressed_file="${BACKUP_ROOT}/clickhouse-backup-${TIMESTAMP}.tar.gz"
    
    tar -czf "$compressed_file" -C "$BACKUP_ROOT" "$TIMESTAMP" 2>&1 || {
        error "Failed to compress backup"
        return 1
    }
    
    # Remove uncompressed directory
    rm -rf "$BACKUP_DIR"
    
    success "Backup compressed: $compressed_file"
    
    # Update backup directory reference
    BACKUP_DIR="$compressed_file"
}

# Clean up old backups
cleanup_old_backups() {
    if [[ "$REMOVE_OLD_BACKUPS" != "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    
    log "Cleaning up old backups (keeping last ${KEEP_BACKUPS_DAYS} days)..."
    
    local deleted_count=0
    
    # Find and remove old backups
    while IFS= read -r -d '' backup; do
        log "  Removing old backup: $backup"
        rm -rf "$backup"
        ((deleted_count++))
    done < <(find "$BACKUP_ROOT" -maxdepth 1 -name "clickhouse-backup-*" -type f -mtime +${KEEP_BACKUPS_DAYS} -print0 2>/dev/null)
    
    while IFS= read -r -d '' backup; do
        log "  Removing old backup directory: $backup"
        rm -rf "$backup"
        ((deleted_count++))
    done < <(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "20*" -mtime +${KEEP_BACKUPS_DAYS} -print0 2>/dev/null)
    
    success "Cleaned up ${deleted_count} old backups"
}

# Display summary
display_summary() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "=========================================="
        echo -e "${YELLOW}DRY RUN COMPLETE${NC}"
        echo "=========================================="
        echo ""
        echo "No actual backup was performed."
        echo "Review the output above to see what would be backed up."
        echo ""
        return
    fi
    
    echo ""
    echo "=========================================="
    echo -e "${GREEN}BACKUP COMPLETE${NC}"
    echo "=========================================="
    echo ""
    echo "Backup Location: $BACKUP_DIR"
    echo "Timestamp: $TIMESTAMP"
    echo ""
    echo "Backup Contents:"
    if [[ -f "$BACKUP_DIR" ]]; then
        echo "  Compressed archive: $(du -h "$BACKUP_DIR" | cut -f1)"
    else
        echo "  Schemas: $(find "${BACKUP_DIR}/schemas" -type f 2>/dev/null | wc -l) files"
        echo "  Data: $(find "${BACKUP_DIR}/data" -type f 2>/dev/null | wc -l) files"
        echo "  Users: $(find "${BACKUP_DIR}/users" -type f 2>/dev/null | wc -l) files"
        echo "  Metadata: $(find "${BACKUP_DIR}/metadata" -type f 2>/dev/null | wc -l) files"
        [[ "$CONFIG_BACKUP" == "true" ]] && echo "  Config: $(find "${BACKUP_DIR}/config" -type f 2>/dev/null | wc -l) files"
    fi
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
    echo "Next steps:"
    echo "1. Verify backup integrity"
    echo "2. Transfer backup to VPS B"
    echo "3. Run restore-vps-b.sh on VPS B"
    echo ""
}

# Main function
main() {
    log "Starting ClickHouse backup process..."
    
    check_root
    parse_arguments "$@"
    check_prerequisites
    
    backup_schemas
    backup_data
    backup_users
    backup_metadata
    backup_config
    create_manifest
    compress_backup
    cleanup_old_backups
    display_summary
}

# Handle script interruption
trap 'error "Backup interrupted"; exit 1' INT TERM

# Run main function
main "$@"
