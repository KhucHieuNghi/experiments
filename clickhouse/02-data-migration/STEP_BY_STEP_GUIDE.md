# Step-by-Step Migration Guide

**Goal:** Migrate 300GB+ ClickHouse data from failing VPS A to VPS B without data loss.

**Time Estimate:** 6-12 hours (depending on network speed and server stability)

---

## Phase 0: Pre-Migration Preparation (30 minutes)

### Step 0.1: Prepare VPS B Environment

**On VPS B (Destination Server):**

```bash
# 1. Connect to VPS B
ssh root@YOUR_VPS_B_IP

# 2. Update system
apt-get update && apt-get upgrade -y

# 3. Create migration directories
mkdir -p /migration/{incoming,logs,backup}
chmod 755 /migration

# 4. Check available disk space (need 400GB+ for 300GB data)
df -h /

# 5. Install ClickHouse (if not installed)
# Follow quickstart/README.md for TLS setup
cd /path/to/clickhouse/quickstart
sudo ./scripts/install.sh

# 6. Configure TLS on VPS B
sudo cp configs/config.d/ssl.xml /etc/clickhouse-server/config.d/
sudo systemctl restart clickhouse-server

# 7. Verify ClickHouse is running
systemctl status clickhouse-server
clickhouse-client --secure --port 9440 -q "SELECT 1"
```

### Step 0.2: Prepare SSH Access

**On VPS B:**

```bash
# Generate SSH key for passwordless access to VPS A
ssh-keygen -t rsa -b 4096 -f /root/.ssh/migration_key -N ""

# Display public key
cat /root/.ssh/migration_key.pub
```

**On VPS A:**

```bash
# Add VPS B's public key to authorized_keys
echo "PASTE_PUBLIC_KEY_HERE" >> /root/.ssh/authorized_keys

# Test connection from VPS B
ssh -i /root/.ssh/migration_key root@YOUR_VPS_A_IP "hostname"
```

### Step 0.3: Prepare Migration Tools on VPS A

**On VPS A:**

```bash
# 1. Copy migration scripts to VPS A
scp -r /path/to/clickhouse/02-data-migration root@YOUR_VPS_A_IP:/opt/

# 2. Connect to VPS A
ssh root@YOUR_VPS_A_IP

# 3. Navigate to migration directory
cd /opt/02-data-migration

# 4. Make scripts executable
chmod +x scripts/*.sh

# 5. Create migration workspace
mkdir -p /migration/{data,logs,schemas}
chmod 755 /migration
```

---

## Phase 1: Assessment (15 minutes)

### Step 1.1: Check VPS A Status

**On VPS A:**

```bash
cd /opt/02-data-migration

# Run assessment
sudo ./scripts/emergency-migrate.sh assess
```

**Expected Output:**
```
[SUCCESS] ClickHouse is running
[INFO] ClickHouse version: 23.x.x
[INFO] Total tables found: 45
[INFO] Total data size: 320 GiB
```

**If ClickHouse is NOT running:**
```bash
# Check data directory size anyway
du -sh /var/lib/clickhouse/data

# Try to start ClickHouse
systemctl start clickhouse-server
systemctl status clickhouse-server

# If still failing, proceed to Strategy B (Direct File Copy)
```

### Step 1.2: Identify Critical Tables

**On VPS A:**

```bash
# View table sizes
cat /migration/emergency/table-sizes.txt

# Identify top 10 largest tables
head -10 /migration/emergency/table-sizes.txt

# Note these down - you'll migrate small ones first, large ones last
```

**Example Output:**
```
db.orders          150000000  rows  180 GiB
db.events          80000000   rows  95 GiB
db.sessions        50000000   rows  45 GiB
...
```

---

## Phase 2: Migration Strategy Selection (5 minutes)

### Decision Tree:

```
Can you run: clickhouse-client -q "SELECT 1" ?
├── YES → Use Strategy A (Table-by-Table Export)
│         └── Best for: Partially working server
│
└── NO  → Use Strategy B (Direct File Copy)
          └── Best for: Completely broken server
```

---

## Phase 3A: Strategy A - Table-by-Table Export (Recommended)

**Use this if ClickHouse can start and respond to queries**

### Step 3A.1: Test Single Table Migration

**On VPS A:**

```bash
# Pick a small table first (under 1GB)
# Check the table-sizes.txt file

# Test export of one small table
sudo ./scripts/emergency-migrate.sh export db.small_table --host YOUR_VPS_B_IP

# Monitor output - should complete without errors
```

**If successful, proceed. If failed, try with smaller batch:**
```bash
# Edit the script to use smaller batch size
export BATCH_SIZE=10000
sudo ./scripts/emergency-migrate.sh export db.small_table --host YOUR_VPS_B_IP
```

### Step 3A.2: Migrate Critical Small Tables First

**On VPS A:**

```bash
# Create a list of critical tables (edit this list)
cat > /migration/critical-tables.txt << 'EOF'
db.users
db.config
db.metadata
db.lookup_table1
db.lookup_table2
EOF

# Migrate critical tables one by one
while read table; do
    echo "Migrating: $table"
    sudo ./scripts/emergency-migrate.sh export "$table" --host YOUR_VPS_B_IP
    sleep 5
done < /migration/critical-tables.txt
```

### Step 3A.3: Start Full Migration

**On VPS A (in a screen/tmux session):**

```bash
# Start screen session (so migration continues if you disconnect)
screen -S migration

# Run full migration
cd /opt/02-data-migration
sudo ./scripts/emergency-migrate.sh export-all --host YOUR_VPS_B_IP

# Detach from screen: Press Ctrl+A, then D

# To reattach later:
screen -r migration
```

### Step 3A.4: Monitor Progress

**On VPS A (new terminal):**

```bash
# Watch migration log
tail -f /migration/emergency/emergency-migration.log

# Check migrated tables
wc -l /migration/emergency/migrated-tables.log

# Check failed tables
wc -l /migration/emergency/failed-tables.log

# Monitor disk usage
df -h /migration/

# Monitor ClickHouse process
top -p $(pgrep clickhouse-server)
```

**On VPS B (verify incoming data):**

```bash
# Check what tables have been created
clickhouse-client --secure --port 9440 -q "SELECT database, count() as tables FROM system.tables WHERE database != 'system' GROUP BY database"

# Check data size
du -sh /var/lib/clickhouse/data/*
```

### Step 3A.5: Handle Failures

**If some tables fail:**

```bash
# View failed tables
cat /migration/emergency/failed-tables.log

# Retry with smaller batch size
sudo ./scripts/emergency-migrate.sh resume
```

**If specific table keeps failing:**
```bash
# Try manual export for problematic table
table="db.problematic_table"
mkdir -p /migration/manual/$table

# Export schema
clickhouse-client --secure --port 9440 -q "SHOW CREATE TABLE $table" > /migration/manual/$table/schema.sql

# Export in very small batches (10K rows)
clickhouse-client --secure --port 9440 -q "SELECT * FROM $table LIMIT 10000 FORMAT TSV" | gzip > /migration/manual/$table/batch_1.tsv.gz

# Transfer to VPS B
scp /migration/manual/$table/* root@YOUR_VPS_B_IP:/migration/incoming/
```

### Step 3A.6: Final Sync (if VPS A still receiving writes)

**If VPS A is still active:**

```bash
# Get last sync timestamp
MAX_TS=$(ssh root@YOUR_VPS_B_IP "clickhouse-client --secure --port 9440 -q 'SELECT max(created_at) FROM db.orders'")

echo "Last sync: $MAX_TS"

# Export only new data
clickhouse-client --secure --port 9440 -q "SELECT * FROM db.orders WHERE created_at > '$MAX_TS' FORMAT TSV" | gzip > /migration/delta_orders.tsv.gz

# Transfer and import
scp /migration/delta_orders.tsv.gz root@YOUR_VPS_B_IP:/tmp/
ssh root@YOUR_VPS_B_IP "zcat /tmp/delta_orders.tsv.gz | clickhouse-client --secure --port 9440 -q 'INSERT INTO db.orders FORMAT TSV'"
```

---

## Phase 3B: Strategy B - Direct File Copy (Emergency Only)

**Use this if ClickHouse won't start at all**

### Step 3B.1: Stop ClickHouse on VPS A

```bash
# Stop ClickHouse to prevent data corruption during copy
systemctl stop clickhouse-server
systemctl status clickhouse-server

# Verify it's stopped
ps aux | grep clickhouse
```

### Step 3B.2: Start File Copy

**On VPS B:**

```bash
# Start screen session
screen -S filecopy

# Copy data files using rsync (with progress and resume)
rsync -avz --progress --bwlimit=0 \
    -e "ssh -i /root/.ssh/migration_key" \
    root@YOUR_VPS_A_IP:/var/lib/clickhouse/ \
    /var/lib/clickhouse/

# This will take several hours for 300GB
# Detach with Ctrl+A, D
```

**Alternative: Using tar + netcat (faster for first copy)**

**On VPS B (receiver):**
```bash
nc -l 12345 | tar -xzf - -C /var/lib/clickhouse/
```

**On VPS A (sender):**
```bash
tar -czf - /var/lib/clickhouse/ | nc YOUR_VPS_B_IP 12345
```

### Step 3B.3: Fix Permissions on VPS B

**After copy completes:**

```bash
# Fix ownership
chown -R clickhouse:clickhouse /var/lib/clickhouse/

# Fix permissions
chmod 755 /var/lib/clickhouse/
chmod 700 /var/lib/clickhouse/data/*
chmod 700 /var/lib/clickhouse/metadata/*

# Copy configuration
rsync -avz -e "ssh -i /root/.ssh/migration_key" \
    root@YOUR_VPS_B_IP:/etc/clickhouse-server/ \
    /etc/clickhouse-server/

chown -R clickhouse:clickhouse /etc/clickhouse-server/
```

### Step 3B.4: Start ClickHouse on VPS B

```bash
# Start ClickHouse
systemctl start clickhouse-server
systemctl status clickhouse-server

# Check logs for errors
tail -f /var/log/clickhouse-server/clickhouse-server.log
```

---

## Phase 4: Verification (30 minutes)

### Step 4.1: Verify All Tables Migrated

**On VPS B:**

```bash
cd /opt/02-data-migration

# Run verification
sudo ./scripts/emergency-migrate.sh verify --host YOUR_VPS_B_IP
```

**Expected Output:**
```
Verification Results
Tables with mismatched row counts:
(none - all match!)
```

### Step 4.2: Manual Row Count Check

**Compare row counts:**

```bash
# On VPS A (if accessible)
clickhouse-client --secure --port 9440 -q "SELECT database, table, sum(rows) FROM system.parts WHERE active GROUP BY database, table ORDER BY database, table" > /tmp/vps_a_counts.txt

# On VPS B
clickhouse-client --secure --port 9440 -q "SELECT database, table, sum(rows) FROM system.parts WHERE active GROUP BY database, table ORDER BY database, table" > /tmp/vps_b_counts.txt

# Compare
diff /tmp/vps_a_counts.txt /tmp/vps_b_counts.txt
```

### Step 4.3: Check Data Integrity

```bash
# Check for corrupted parts
clickhouse-client --secure --port 9440 -q "SELECT database, table, name, active FROM system.parts WHERE active = 0"

# Should return empty or very few results

# Run check on suspicious tables
clickhouse-client --secure --port 9440 -q "CHECK TABLE db.large_table"
```

### Step 4.4: Test Queries

```bash
# Run test queries
clickhouse-client --secure --port 9440 -q "SELECT count() FROM db.orders"
clickhouse-client --secure --port 9440 -q "SELECT * FROM db.orders LIMIT 10"
clickhouse-client --secure --port 9440 -q "SELECT toDate(created_at) as date, count() FROM db.orders GROUP BY date ORDER BY date DESC LIMIT 7"
```

---

## Phase 5: Cutover (15 minutes)

### Step 5.1: Stop Writes to VPS A

**If VPS A is still active:**

```bash
# Stop application writes
# Option 1: Update application config to stop writing
# Option 2: Block incoming connections
iptables -A INPUT -p tcp --dport 9440 -j DROP
iptables -A INPUT -p tcp --dport 8443 -j DROP
```

### Step 5.2: Final Sync

```bash
# Run final delta sync if needed
sudo ./scripts/emergency-migrate.sh export-all --host YOUR_VPS_B_IP
```

### Step 5.3: Update Application Configuration

**Update your application to connect to VPS B:**

```
# Old config (VPS A)
host: vps-a.example.com
port: 9440
secure: true

# New config (VPS B)
host: vps-b.example.com
port: 9440
secure: true
```

### Step 5.4: Start Application on VPS B

```bash
# Start application
systemctl start your-app

# Verify application can connect
clickhouse-client --secure --port 9440 -q "SELECT count() FROM db.orders"
```

---

## Phase 6: Post-Migration (Ongoing)

### Step 6.1: Monitor VPS B

```bash
# Check ClickHouse status
systemctl status clickhouse-server

# Monitor resources
htop

# Check logs
tail -f /var/log/clickhouse-server/clickhouse-server.log
```

### Step 6.2: Keep VPS A Running (Temporarily)

**DO NOT delete data from VPS A yet!**

Keep VPS A running for 24-48 hours as backup in case issues are discovered.

### Step 6.3: Final Cleanup (After 48 hours)

**Once confirmed everything works:**

```bash
# On VPS A - Shutdown ClickHouse
systemctl stop clickhouse-server

# Backup VPS A config (just in case)
tar -czf /root/clickhouse-config-backup.tar.gz /etc/clickhouse-server/

# You can now decommission VPS A
```

---

## Quick Reference: Common Commands

```bash
# Check migration progress
tail -f /migration/emergency/emergency-migration.log

# See what's currently migrating
ps aux | grep clickhouse-client

# Check disk space
df -h

# Check network usage
iftop -i eth0

# Resume failed tables
sudo ./scripts/emergency-migrate.sh resume

# Restart migration from specific table
sudo ./scripts/emergency-migrate.sh export db.specific_table --host YOUR_VPS_B_IP
```

---

## Troubleshooting

### Problem: Migration keeps failing on large table

**Solution:** Use smaller batch size
```bash
# Edit script to use 10K instead of 1M rows
export BATCH_SIZE=10000
sudo ./scripts/emergency-migrate.sh export db.large_table --host YOUR_VPS_B_IP
```

### Problem: Network connection drops

**Solution:** Use screen/tmux
```bash
# Start in screen
screen -S migration

# Run command
sudo ./scripts/emergency-migrate.sh export-all --host YOUR_VPS_B_IP

# Detach: Ctrl+A, D

# Reattach: screen -r migration
```

### Problem: Disk full on VPS B

**Solution:** Check and clean up
```bash
# Check disk usage
df -h

# Clean up old backups
rm -rf /migration/incoming/*/batch_*.tsv.gz

# Expand disk or delete non-essential files
```

### Problem: Row counts don't match after migration

**Solution:** Identify missing data
```bash
# Compare specific table
clickhouse-client --secure --port 9440 -q "SELECT count() FROM db.orders WHERE created_at > '2024-01-01'"

# Export missing range
clickhouse-client --secure --port 9440 -q "SELECT * FROM db.orders WHERE id > LAST_MIGRATED_ID FORMAT TSV" | gzip > missing.tsv.gz
```

---

## Summary Checklist

- [ ] VPS B prepared with ClickHouse and TLS
- [ ] SSH access configured between servers
- [ ] Assessment completed on VPS A
- [ ] Migration strategy chosen (A or B)
- [ ] Small tables migrated first
- [ ] Large tables migrated with monitoring
- [ ] Failed tables retried
- [ ] Row counts verified match
- [ ] Test queries executed successfully
- [ ] Application cutover to VPS B
- [ ] VPS A kept as backup for 48 hours

---

**Remember:** Data safety first! Never delete from VPS A until VPS B is fully verified.
