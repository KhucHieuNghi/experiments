# Emergency Data Migration - Failing Source Server

## ⚠️ CRITICAL SITUATION: VPS A is Failing

**Scenario:**
- VPS A ClickHouse server has errors and cannot be fixed
- VPS A contains 300GB+ of critical data
- Must migrate to VPS B without data loss
- Standard backup scripts may not work due to server instability

## Migration Strategy Decision Tree

```
Can ClickHouse start?
├── YES (even intermittently)
│   └── Strategy A: Table-by-Table Export with Resume
│       - Export data in chunks
│       - Handle partial failures
│       - Verify each table
│
└── NO (server completely down)
    └── Strategy B: Direct Data File Copy
        - Copy raw data files
        - Requires same ClickHouse version
        - May have some data loss if files corrupted
```

---

## Strategy A: Table-by-Table Export (Recommended if ClickHouse starts)

### Prerequisites

```bash
# Check if ClickHouse can start
sudo systemctl start clickhouse-server
sudo systemctl status clickhouse-server

# If it starts, check basic functionality
clickhouse-client --secure --port 9440 -q "SELECT 1"
```

### Phase 1: Assessment

```bash
# Create migration working directory
mkdir -p /migration/emergency
cd /migration/emergency

# Get list of all databases and tables
clickhouse-client --secure --port 9440 -q "SELECT concat(database, '.', name) FROM system.tables WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') FORMAT TSV" > tables.txt

# Get row counts and sizes for prioritization
clickhouse-client --secure --port 9440 -q "SELECT database, table, sum(rows) as rows, formatReadableSize(sum(bytes)) as size FROM system.parts WHERE database NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA') GROUP BY database, table ORDER BY sum(bytes) DESC FORMAT TSV" > table_sizes.txt

cat table_sizes.txt
```

### Phase 2: Priority-Based Migration

**Migration Order:**
1. Small tables first (validation and testing)
2. Critical business tables
3. Large tables (with chunking)
4. System tables last

```bash
#!/bin/bash
# emergency-migrate.sh

TABLES_FILE="tables.txt"
BATCH_SIZE=1000000  # Rows per batch
MIGRATION_LOG="migration.log"
FAILED_LOG="failed_tables.log"

# Create logs
touch "$MIGRATION_LOG"
touch "$FAILED_LOG"

# Function to migrate single table with resume capability
migrate_table() {
    local full_table=$1
    local database=${full_table%%.*}
    local table=${full_table#*.}
    
    echo "=========================================="
    echo "Migrating: $full_table"
    echo "=========================================="
    
    # Check if already migrated
    if grep -q "^$full_table$" "$MIGRATION_LOG"; then
        echo "Already migrated: $full_table (skipping)"
        return 0
    fi
    
    # Get table schema
    clickhouse-client --secure --port 9440 -q "SHOW CREATE TABLE $full_table" > "${full_table}.sql" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo "FAILED: Cannot get schema for $full_table" | tee -a "$FAILED_LOG"
        return 1
    fi
    
    # Get total row count
    total_rows=$(clickhouse-client --secure --port 9440 -q "SELECT count() FROM $full_table" 2>/dev/null)
    
    if [ -z "$total_rows" ] || [ "$total_rows" -eq 0 ]; then
        echo "Table $full_table is empty or inaccessible"
        echo "$full_table" >> "$MIGRATION_LOG"
        return 0
    fi
    
    echo "Total rows: $total_rows"
    
    # Export data in batches
    offset=0
    batch=1
    success=true
    
    while [ $offset -lt $total_rows ]; do
        echo "Exporting batch $batch (offset: $offset, limit: $BATCH_SIZE)"
        
        output_file="${full_table}_batch_${batch}.native"
        
        clickhouse-client --secure --port 9440 -q "SELECT * FROM $full_table LIMIT $BATCH_SIZE OFFSET $offset FORMAT Native" > "$output_file" 2>&1
        
        if [ $? -eq 0 ] && [ -s "$output_file" ]; then
            # Compress and transfer immediately
            gzip "$output_file"
            scp -P 22 "${output_file}.gz" user@vps-b:/migration/incoming/ 2>&1
            
            if [ $? -eq 0 ]; then
                echo "Batch $batch transferred successfully"
                rm "${output_file}.gz"
                offset=$((offset + BATCH_SIZE))
                batch=$((batch + 1))
            else
                echo "ERROR: Failed to transfer batch $batch"
                success=false
                break
            fi
        else
            echo "ERROR: Failed to export batch $batch"
            cat "$output_file" >> error.log
            success=false
            break
        fi
        
        # Add delay to reduce load on failing server
        sleep 2
    done
    
    if [ "$success" = true ]; then
        echo "$full_table" >> "$MIGRATION_LOG"
        echo "SUCCESS: Migrated $full_table"
        return 0
    else
        echo "FAILED: $full_table (partial migration)" | tee -a "$FAILED_LOG"
        return 1
    fi
}

# Main migration loop
while IFS= read -r table; do
    migrate_table "$table" || true
    
    # Add delay between tables to not overwhelm server
    sleep 5
done < "$TABLES_FILE"

echo "=========================================="
echo "Migration Summary"
echo "=========================================="
echo "Total tables: $(wc -l < "$TABLES_FILE")"
echo "Migrated: $(wc -l < "$MIGRATION_LOG")"
echo "Failed: $(wc -l < "$FAILED_LOG")"
```

### Phase 3: Parallel Transfer for Large Tables

For very large tables (>50GB), use parallel streams:

```bash
#!/bin/bash
# parallel-export.sh

FULL_TABLE=$1  # e.g., "db.large_table"
NUM_STREAMS=4  # Number of parallel streams

echo "Exporting $FULL_TABLE with $NUM_STREAMS parallel streams..."

# Create named pipes
for i in $(seq 1 $NUM_STREAMS); do
    mkfifo "/tmp/stream_$i.pipe"
done

# Start parallel exports
for i in $(seq 1 $NUM_STREAMS); do
    (
        clickhouse-client --secure --port 9440 -q "SELECT * FROM $FULL_TABLE WHERE cityHash64(*) % $NUM_STREAMS = $i-1 FORMAT Native" > "/tmp/stream_$i.pipe" 2>"/tmp/stream_$i.log"
    ) &
done

# Transfer to VPS B in parallel
for i in $(seq 1 $NUM_STREAMS); do
    (
        ssh user@vps-b "cat > /migration/incoming/${FULL_TABLE}_stream_$i.native" < "/tmp/stream_$i.pipe"
    ) &
done

# Wait for all processes
wait

# Cleanup
rm -f /tmp/stream_*.pipe /tmp/stream_*.log

echo "Parallel export complete for $FULL_TABLE"
```

---

## Strategy B: Direct Data File Copy (If ClickHouse Won't Start)

### ⚠️ Warning

- Requires **same ClickHouse version** on both servers
- May lose recent data if files corrupted
- Must preserve file permissions and ownership
- Stop ClickHouse on VPS A if possible before copying

### Phase 1: Prepare VPS B

```bash
# On VPS B - Install same ClickHouse version as VPS A
# Check version on VPS A (if possible)
clickhouse-client --version

# Or check binary
ls -la /usr/bin/clickhouse*

# Install matching version on VPS B
# See quickstart/README.md for installation
```

### Phase 2: Copy Data Files (Two-Pass Rsync)

To minimize downtime, do an initial sync while ClickHouse is running, then stop ClickHouse and perform a quick second sync for deltas.

```bash
#!/bin/bash
# direct-copy.sh

VPS_A_IP="vps-a-ip"
VPS_B_IP="vps-b-ip"
DATA_DIR="/var/lib/clickhouse"
CONFIG_DIR="/etc/clickhouse-server"

echo "PASS 1: Initial sync (ClickHouse RUNNING on VPS A)..."
# This copies 99% of data with ZERO downtime
rsync -av --progress --bwlimit=50000 \
    -e "ssh -p 22" \
    root@${VPS_A_IP}:${DATA_DIR}/ \
    ${DATA_DIR}/

echo "PASS 2: Final delta sync (ClickHouse STOPPED on VPS A)..."
# First, stop ClickHouse on VPS A
ssh root@${VPS_A_IP} "systemctl stop clickhouse-server"

# Second rsync catches the few files that changed since Pass 1 (takes seconds/minutes)
rsync -avz --progress --delete \
    -e "ssh -p 22" \
    root@${VPS_A_IP}:${DATA_DIR}/ \
    ${DATA_DIR}/

# Copy configuration
rsync -avz -e "ssh -p 22" \
    root@${VPS_A_IP}:${CONFIG_DIR}/ \
    ${CONFIG_DIR}/
```

### Phase 3: Fix Permissions and Start

```bash
# Fix ownership
sudo chown -R clickhouse:clickhouse ${DATA_DIR}/
sudo chown -R clickhouse:clickhouse ${CONFIG_DIR}/

# Fix permissions
sudo chmod 755 ${DATA_DIR}/
sudo chmod 700 ${DATA_DIR}/data/*
sudo chmod 700 ${DATA_DIR}/metadata/*

# Start ClickHouse
sudo systemctl start clickhouse-server
sudo systemctl status clickhouse-server

# Check logs for errors
sudo tail -f /var/log/clickhouse-server/clickhouse-server.log
```

### Phase 4: Data Verification

```bash
# Check for corrupted parts
clickhouse-client --secure --port 9440 -q "SELECT database, table, name, active FROM system.parts WHERE active = 0"

# Check for missing data
clickhouse-client --secure --port 9440 -q "SELECT database, count() as tables FROM system.tables WHERE database NOT IN ('system', 'information_schema') GROUP BY database"

# Run check on all tables
clickhouse-client --secure --port 9440 -q "SELECT concat('CHECK TABLE ', database, '.', name) FROM system.tables WHERE database NOT IN ('system', 'information_schema') FORMAT TSV" | while read cmd; do
    echo "Running: $cmd"
    clickhouse-client --secure --port 9440 -q "$cmd" 2>&1 | head -5
done
```

---

## Strategy C: Hybrid Approach (Recommended for 300GB+)

Combine both strategies for maximum safety:

### Phase 1: Critical Tables First (Export Method)

```bash
# Migrate critical small tables first using export method
# This ensures business continuity even if direct copy fails

CRITICAL_TABLES="
db.orders
db.customers
db.transactions
db.users
"

for table in $CRITICAL_TABLES; do
    ./emergency-migrate.sh "$table"
done
```

### Phase 2: Large Tables (Parallel Export + Direct Copy Backup)

```bash
# For large tables, run parallel export
# While also copying data files in background as backup

# Terminal 1: Export large tables
./parallel-export.sh db.large_table_1 &
./parallel-export.sh db.large_table_2 &
wait

# Terminal 2: Background data file copy (fallback)
rsync -avz --progress root@vps-a:/var/lib/clickhouse/data/db/large_table_* /var/lib/clickhouse/data/db/
```

### Phase 3: Data Synchronization (Warnings)

> [!WARNING]
> It is extremely dangerous to perform delta synchronizations based strictly on timestamps (e.g. `SELECT * WHERE timestamp > MAX_TIMESTAMP`). This requires monotonically increasing timestamps and perfectly ordered inserts on the source and ignores out-of-order inserts, background mutations, or updates. If you require zero-downtime streaming sync, rely instead on Native Replication (`ReplicatedMergeTree`) or the native ClickHouse `BACKUP`/`RESTORE` features.

If you must use query-based sync, only do so if your insertion logic strictly guarantees timestamp safety.

---

## Data Integrity Verification

### Row Count Verification

```bash
#!/bin/bash
# verify-migration.sh

echo "Comparing row counts between VPS A and VPS B..."

# Get tables from VPS A
ssh root@vps-a "clickhouse-client -q \"SELECT concat(database, '.', table, ':', toString(sum(rows))) FROM system.parts WHERE active GROUP BY database, table FORMAT TSV\"" > vps_a_counts.txt

# Get tables from VPS B
clickhouse-client --secure --port 9440 -q "SELECT concat(database, '.', table, ':', toString(sum(rows))) FROM system.parts WHERE active GROUP BY database, table FORMAT TSV" > vps_b_counts.txt

# Compare
echo "Tables with mismatched row counts:"
comm -3 <(sort vps_a_counts.txt) <(sort vps_b_counts.txt)
```

### Checksum Verification

```bash
# For critical tables, verify aggregate checksums
# This produces a single row with count + hash sum for easy comparison

TABLE="db.critical_table"

# Get checksum from VPS A
ssh root@vps-a "clickhouse-client --secure --port 9440 -q \"SELECT count(), sum(cityHash64(*)) FROM $TABLE\""

# Get checksum from VPS B
clickhouse-client --secure --port 9440 -q "SELECT count(), sum(cityHash64(*)) FROM $TABLE"

# Both should output the same count and hash sum
```

---

## Handling Partial Failures

### Resume Failed Tables

```bash
# Get list of failed tables
cat failed_tables.log

# Retry failed tables with smaller batches
for table in $(cat failed_tables.log); do
    BATCH_SIZE=10000  # Smaller batch
    ./emergency-migrate.sh "$table"
done
```

### Skip Corrupted Parts

```bash
# If table has corrupted parts, skip them
clickhouse-client --secure --port 9440 -q "SELECT name FROM system.parts WHERE database = 'db' AND table = 'table_name' AND active = 0"

# Detach corrupted parts
clickhouse-client --secure --port 9440 -q "ALTER TABLE db.table_name DETACH PART 'corrupted_part_name'"

# Continue migration
```

---

## Monitoring and Recovery

### Real-time Progress Monitoring

```bash
# Monitor disk usage
df -h /var/lib/clickhouse/ /migration/

# Monitor network transfer
iftop -i eth0

# Monitor ClickHouse processes
watch -n 5 'ps aux | grep clickhouse'

# Monitor logs
tail -f /var/log/clickhouse-server/clickhouse-server.log
```

### Emergency Rollback

If migration fails catastrophically:

```bash
# Keep VPS A running if possible
# Don't delete data from VPS A until VPS B is fully verified

# If VPS B has issues, restart from backup
sudo systemctl stop clickhouse-server
sudo rm -rf /var/lib/clickhouse/data/*
sudo rm -rf /var/lib/clickhouse/metadata/*

# Restore from backup (if available)
# Or restart migration process
```

---

## Best Practices for 300GB+ Migration

1. **Start with small tables** - Validate process first
2. **Use screen/tmux** - Sessions survive disconnections
3. **Monitor disk space** - 300GB source needs 400GB+ destination
4. **Bandwidth planning** - 300GB over 1Gbps = ~40 minutes minimum
5. **Parallel streams** - Use multiple connections for large tables
6. **Incremental sync** - After bulk transfer, sync deltas
7. **Verify early and often** - Check row counts after each table
8. **Document everything** - Log all errors and decisions
9. **Have a rollback plan** - Keep VPS A alive until verified
10. **Test application connectivity** - Before switching production traffic

---

## Quick Command Reference

```bash
# Check table sizes
clickhouse-client --secure --port 9440 -q "SELECT database, table, formatReadableSize(sum(bytes)) FROM system.parts WHERE active GROUP BY database, table ORDER BY sum(bytes) DESC"

# Export single table
clickhouse-client --secure --port 9440 -q "SELECT * FROM db.table FORMAT Native" | gzip > table.native.gz

# Import single table
gunzip < table.native.gz | clickhouse-client --secure --port 9440 -q "INSERT INTO db.table FORMAT Native"

# Check replication lag (if using)
clickhouse-client --secure --port 9440 -q "SELECT * FROM system.replicas FORMAT Vertical"

# Check for errors
clickhouse-client --secure --port 9440 -q "SELECT * FROM system.replication_queue WHERE last_exception != ''"
```

---

## When to Seek Help

Contact ClickHouse support or community if:
- Data corruption is severe (>50% of tables affected)
- ClickHouse cannot start even in single-user mode
- Filesystem errors on VPS A
- Repeated migration failures with same error
- Need to recover specific corrupted parts

**Remember:** Never delete data from VPS A until VPS B is fully operational and verified!
