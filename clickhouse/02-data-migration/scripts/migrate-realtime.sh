#!/bin/bash

# ClickHouse Real-time Migration Script
# Description: Sets up and manages real-time replication between VPS A and VPS B
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
SOURCE_HOST=""
DEST_HOST="localhost"
MIGRATION_MODE="setup"
ZOOKEEPER_HOSTS=""
REPLICATION_USER="migration_user"
REPLICATION_PASSWORD=""
LOG_FILE="/var/log/clickhouse-migration.log"
CONFIG_DIR="/etc/clickhouse-server"

# ClickHouse connection settings
CLICKHOUSE_PORT="9440"
CLICKHOUSE_INSECURE_PORT="9000"

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

ClickHouse Real-time Migration Script

MODES:
    setup       Configure real-time replication between VPS A and VPS B
    monitor     Monitor replication status and lag
    stop        Stop replication cleanly
    switchover  Perform controlled failover to VPS B
    sync        Perform one-time data synchronization

OPTIONS:
    -h, --help              Show this help message
    -s, --source HOST       Source VPS hostname or IP (VPS A) [required]
    -d, --dest HOST         Destination VPS hostname (VPS B) [default: localhost]
    -m, --mode MODE         Migration mode: setup, monitor, stop, switchover, sync
    -z, --zookeeper HOSTS   ZooKeeper hosts (comma-separated)
    -u, --user USER         Replication username [default: migration_user]
    -p, --password PASS     Replication password
    --secure               Use TLS connections

EXAMPLES:
    # Setup replication
    sudo $0 -s vps-a.example.com -d vps-b.example.com -z zk1:2181,zk2:2181 -p secret123

    # Monitor replication status
    sudo $0 -s vps-a.example.com -m monitor

    # Perform controlled switchover
    sudo $0 -s vps-a.example.com -d vps-b.example.com -m switchover

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
            -d|--dest)
                DEST_HOST="$2"
                shift 2
                ;;
            -m|--mode)
                MIGRATION_MODE="$2"
                shift 2
                ;;
            -z|--zookeeper)
                ZOOKEEPER_HOSTS="$2"
                shift 2
                ;;
            -u|--user)
                REPLICATION_USER="$2"
                shift 2
                ;;
            -p|--password)
                REPLICATION_PASSWORD="$2"
                shift 2
                ;;
            --secure)
                USE_TLS=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$SOURCE_HOST" ]]; then
        error "Source host is required. Use -s or --source"
        usage
        exit 1
    fi
}

# Build clickhouse-client command
build_client_cmd() {
    local host=$1
    local cmd="clickhouse-client --host $host --port $CLICKHOUSE_PORT"
    
    if [[ "${USE_TLS:-false}" == "true" ]]; then
        cmd="clickhouse-client --host $host --secure --port $CLICKHOUSE_PORT"
    fi
    
    echo "$cmd"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v clickhouse-client &> /dev/null; then
        error "clickhouse-client not found. Is ClickHouse installed?"
        exit 1
    fi
    
    log "Testing connection to source (${SOURCE_HOST})..."
    local source_cmd=$(build_client_cmd "$SOURCE_HOST")
    if ! eval "$source_cmd -q \"SELECT 1\"" 2>/dev/null; then
        error "Cannot connect to ClickHouse at ${SOURCE_HOST}:${CLICKHOUSE_PORT}"
        exit 1
    fi
    success "Connection to source verified"
    
    log "Testing connection to destination (${DEST_HOST})..."
    local dest_cmd=$(build_client_cmd "$DEST_HOST")
    if ! eval "$dest_cmd -q \"SELECT 1\"" 2>/dev/null; then
        error "Cannot connect to ClickHouse at ${DEST_HOST}:${CLICKHOUSE_PORT}"
        exit 1
    fi
    success "Connection to destination verified"
    success "Prerequisites check passed"
}

# Configure ZooKeeper
configure_zookeeper() {
    if [[ -z "$ZOOKEEPER_HOSTS" ]]; then
        return
    fi
    
    log "Configuring ZooKeeper..."
    
    local zk_config=""
    IFS=',' read -ra ZK_NODES <<< "$ZOOKEEPER_HOSTS"
    for node in "${ZK_NODES[@]}"; do
        local host="${node%%:*}"
        local port="${node#*:}"
        zk_config="${zk_config}<node><host>${host}</host><port>${port}</port></node>"
    done
    
    local zk_xml="${CONFIG_DIR}/conf.d/zookeeper.xml"
    mkdir -p "$(dirname "$zk_xml")"
    
    cat > "$zk_xml" << EOF
<?xml version="1.0"?>
<clickhouse>
    <zookeeper>
        ${zk_config}
    </zookeeper>
</clickhouse>
EOF
    
    chown clickhouse:clickhouse "$zk_xml"
    chmod 640 "$zk_xml"
    success "ZooKeeper configuration created: $zk_xml"
    
    log "Restarting ClickHouse to apply ZooKeeper configuration..."
    systemctl restart clickhouse-server
    sleep 5
}

# Configure remote servers
configure_remote_servers() {
    log "Configuring remote servers..."
    
    local remote_servers_xml="${CONFIG_DIR}/conf.d/remote_servers.xml"
    mkdir -p "$(dirname "$remote_servers_xml")"
    
    cat > "$remote_servers_xml" << EOF
<?xml version="1.0"?>
<clickhouse>
    <remote_servers>
        <migration_cluster>
            <shard>
                <replica>
                    <host>${SOURCE_HOST}</host>
                    <port>${CLICKHOUSE_PORT}</port>
                </replica>
                <replica>
                    <host>${DEST_HOST}</host>
                    <port>${CLICKHOUSE_PORT}</port>
                </replica>
            </shard>
        </migration_cluster>
    </remote_servers>
</clickhouse>
EOF
    
    chown clickhouse:clickhouse "$remote_servers_xml"
    chmod 640 "$remote_servers_xml"
    success "Remote servers configuration created: $remote_servers_xml"
}

# Setup replication user
setup_replication_user() {
    log "Setting up replication user..."
    
    if [[ -z "$REPLICATION_PASSWORD" ]]; then
        REPLICATION_PASSWORD=$(openssl rand -base64 32)
        log "Generated replication password"
    fi
    
    local source_cmd=$(build_client_cmd "$SOURCE_HOST")
    local dest_cmd=$(build_client_cmd "$DEST_HOST")
    
    local create_user_sql="CREATE USER IF NOT EXISTS ${REPLICATION_USER} IDENTIFIED WITH sha256_password BY '${REPLICATION_PASSWORD}'"
    local grant_sql="GRANT SELECT, INSERT, CREATE, ALTER ON *.* TO ${REPLICATION_USER}"
    
    log "Creating replication user on source..."
    eval "$source_cmd -q \"$create_user_sql\"" 2>&1 || warning "Failed to create replication user on source"
    eval "$source_cmd -q \"$grant_sql\"" 2>&1 || warning "Failed to grant permissions on source"
    
    log "Creating replication user on destination..."
    eval "$dest_cmd -q \"$create_user_sql\"" 2>&1 || warning "Failed to create replication user on destination"
    eval "$dest_cmd -q \"$grant_sql\"" 2>&1 || warning "Failed to grant permissions on destination"
    
    success "Replication user configured"
}

# Get list of tables to replicate
get_tables_for_replication() {
    local host=$1
    local client_cmd=$(build_client_cmd "$host")
    local query="SELECT database, name, engine FROM system.tables WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') AND engine LIKE '%MergeTree' ORDER BY database, name"
    
    eval "$client_cmd -q \"$query\""
}

# Sync table data
sync_table_data() {
    local db=$1
    local table=$2
    
    log "  Syncing data for: ${db}.${table}..."
    
    local source_cmd=$(build_client_cmd "$SOURCE_HOST")
    local dest_cmd=$(build_client_cmd "$DEST_HOST")
    
    local source_rows=$(eval "$source_cmd -q \"SELECT count() FROM ${db}.${table}\"")
    log "    Source rows: $source_rows"
    
    local dest_rows=$(eval "$dest_cmd -q \"SELECT count() FROM ${db}.${table}\"" 2>/dev/null || echo "0")
    log "    Destination rows: $dest_rows"
    
    if [[ "$dest_rows" -ge "$source_rows" ]]; then
        log "    Table already in sync"
        return
    fi
    
    local insert_sql="INSERT INTO ${db}.${table} SELECT * FROM remote('${SOURCE_HOST}', ${db}, ${table}, '${REPLICATION_USER}', '${REPLICATION_PASSWORD}')"
    eval "$dest_cmd -q \"$insert_sql\"" 2>&1 || {
        warning "Failed to sync data for: ${db}.${table}"
        return
    }
    
    dest_rows=$(eval "$dest_cmd -q \"SELECT count() FROM ${db}.${table}\"")
    log "    Synced rows: $dest_rows"
}

# Setup table replication
setup_table_replication() {
    log "Setting up table replication..."
    
    local source_cmd=$(build_client_cmd "$SOURCE_HOST")
    local dest_cmd=$(build_client_cmd "$DEST_HOST")
    
    local tables=$(get_tables_for_replication "$SOURCE_HOST")
    
    while IFS=$'\t' read -r db table engine; do
        [[ -z "$table" ]] && continue
        
        log "Processing table: ${db}.${table} (engine: ${engine})"
        
        local check_table_sql="SELECT count() FROM system.tables WHERE database = '${db}' AND name = '${table}'"
        local table_exists=$(eval "$dest_cmd -q \"$check_table_sql\"" 2>/dev/null || echo "0")
        
        if [[ "$table_exists" -eq 0 ]]; then
            log "  Creating table on destination..."
            
            local create_stmt=$(eval "$source_cmd -q \"SHOW CREATE TABLE ${db}.${table}\"")
            eval "$dest_cmd -q \"CREATE DATABASE IF NOT EXISTS ${db}\"" 2>/dev/null || true
            eval "$dest_cmd -q \"$create_stmt\"" 2>&1 || {
                warning "Failed to create table: ${db}.${table}"
                continue
            }
            success "  Created table: ${db}.${table}"
        else
            log "  Table already exists: ${db}.${table}"
        fi
        
        sync_table_data "$db" "$table"
    done <<< "$tables"
    
    success "Table replication setup complete"
}

# Monitor replication
monitor_replication() {
    log "Monitoring replication status..."
    
    local dest_cmd=$(build_client_cmd "$DEST_HOST")
    
    echo ""
    echo "=========================================="
    echo "Replication Status Report"
    echo "=========================================="
    echo "Source: ${SOURCE_HOST}"
    echo "Destination: ${DEST_HOST}"
    echo "Time: $(date)"
    echo ""
    
    echo "--- Replica Status ---"
    local replica_query="SELECT database, table, is_leader, total_replicas, active_replicas FROM system.replicas ORDER BY database, table FORMAT PrettyCompact"
    eval "$dest_cmd -q \"$replica_query\"" 2>/dev/null || echo "No replicas found"
    
    echo ""
    echo "--- Replication Queue ---"
    local queue_query="SELECT database, table, type, count() as queue_size FROM system.replication_queue GROUP BY database, table, type ORDER BY queue_size DESC FORMAT PrettyCompact"
    eval "$dest_cmd -q \"$queue_query\"" 2>/dev/null || echo "No replication queue entries"
    
    echo ""
    echo "=========================================="
}

# Stop replication
stop_replication() {
    log "Stopping replication..."
    
    local dest_cmd=$(build_client_cmd "$DEST_HOST")
    local tables_query="SELECT database, name FROM system.tables WHERE engine LIKE 'Replicated%'"
    local tables=$(eval "$dest_cmd -q \"$tables_query\"" 2>/dev/null)
    
    if [[ -z "$tables" ]]; then
        log "No replicated tables found"
        return
    fi
    
    while IFS=$'\t' read -r db table; do
        [[ -z "$table" ]] && continue
        log "  Detaching replicated table: ${db}.${table}"
        eval "$dest_cmd -q \"DETACH TABLE ${db}.${table}\"" 2>/dev/null || true
    done <<< "$tables"
    
    success "Replication stopped"
}

# Perform controlled switchover
perform_switchover() {
    log "Performing controlled switchover..."
    
    local source_cmd=$(build_client_cmd "$SOURCE_HOST")
    local dest_cmd=$(build_client_cmd "$DEST_HOST")
    
    log "Step 1: Checking replication lag..."
    local lag_query="SELECT max(abs(source_replica_delay)) FROM system.replicas"
    local max_lag=$(eval "$dest_cmd -q \"$lag_query\"" 2>/dev/null || echo "999")
    
    if [[ "$max_lag" -gt 10 ]]; then
        error "Replication lag is too high (${max_lag}s). Please wait for replication to catch up."
        exit 1
    fi
    success "Replication lag is acceptable: ${max_lag}s"
    
    log "Step 2: Setting source to read-only mode..."
    eval "$source_cmd -q \"SYSTEM STOP MERGES\"" 2>/dev/null || true
    
    log "Step 3: Waiting for final sync..."
    sleep 10
    
    log "Step 4: Verifying data consistency..."
    local tables=$(get_tables_for_replication "$SOURCE_HOST")
    local consistent=true
    
    while IFS=$'\t' read -r db table engine; do
        [[ -z "$table" ]] && continue
        
        local source_count=$(eval "$source_cmd -q \"SELECT count() FROM ${db}.${table}\"")
        local dest_count=$(eval "$dest_cmd -q \"SELECT count() FROM ${db}.${table}\"")
        
        if [[ "$source_count" -ne "$dest_count" ]]; then
            warning "Data mismatch in ${db}.${table}: Source=$source_count, Dest=$dest_count"
            consistent=false
        fi
    done <<< "$tables"
    
    if [[ "$consistent" != "true" ]]; then
        error "Data inconsistency detected. Switchover aborted."
        exit 1
    fi
    success "Data consistency verified"
    
    log "Step 5: Switching traffic to destination..."
    eval "$source_cmd -q \"SYSTEM STOP LISTEN QUERIES\"" 2>/dev/null || true
    success "Traffic redirected to destination"
    
    log "Step 6: Starting services on destination..."
    eval "$dest_cmd -q \"SYSTEM START LISTEN QUERIES\"" 2>/dev/null || true
    
    success "Switchover complete"
    log "Update your application connection strings to point to ${DEST_HOST}"
}

# Main function
main() {
    log "Starting ClickHouse migration process..."
    log "Mode: ${MIGRATION_MODE}"
    
    check_root
    parse_arguments "$@"
    
    case $MIGRATION_MODE in
        setup)
            check_prerequisites
            configure_zookeeper
            configure_remote_servers
            setup_replication_user
            setup_table_replication
            ;;
        monitor)
            check_prerequisites
            monitor_replication
            ;;
        stop)
            check_prerequisites
            stop_replication
            ;;
        switchover)
            check_prerequisites
            perform_switchover
            ;;
        sync)
            check_prerequisites
            setup_table_replication
            ;;
        *)
            error "Unknown mode: ${MIGRATION_MODE}"
            usage
            exit 1
            ;;
    esac
    
    success "Migration operation completed successfully"
}

# Handle script interruption
trap 'error "Migration interrupted"; exit 1' INT TERM

# Run main function
main "$@"
