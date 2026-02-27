# ClickHouse Data Migration Guide

This guide covers migrating data between ClickHouse VPS instances, including backup, restore, and real-time replication setup.

## 📋 Quick Start: Step-by-Step Migration

**New to migration? Follow the [STEP_BY_STEP_GUIDE.md](STEP_BY_STEP_GUIDE.md)**

This guide walks you through:
- Phase 0: Pre-migration preparation (VPS B setup)
- Phase 1: Assessment of VPS A
- Phase 2: Strategy selection
- Phase 3: Migration execution (with monitoring)
- Phase 4: Data verification
- Phase 5: Application cutover

**Time estimate:** 6-12 hours for 300GB+ datasets

---

## ⚠️ Emergency Migration

**If VPS A is failing/corrupted with 300GB+ data:**

1. **Read:** [EMERGENCY_MIGRATION.md](EMERGENCY_MIGRATION.md) - Strategies and procedures
2. **Follow:** [STEP_BY_STEP_GUIDE.md](STEP_BY_STEP_GUIDE.md) - Detailed execution steps
3. **Use:** `emergency-migrate.sh` script - Automated with resume capability

Emergency scenarios covered:
- ClickHouse server won't start
- Server instability during migration  
- Large dataset (300GB+) migration
- Resume capability for failed transfers
- Data integrity verification

Quick commands:
```bash
# Assess the situation
sudo ./scripts/emergency-migrate.sh assess

# Export all tables with resume capability  
sudo ./scripts/emergency-migrate.sh export-all --host vps-b.example.com

# Or direct file copy if ClickHouse won't start
sudo ./scripts/emergency-migrate.sh copy-files --host vps-b.example.com

# Verify migration
sudo ./scripts/emergency-migrate.sh verify --host vps-b.example.com
```

---

## Overview

This directory contains tools and scripts for:
- **Backup VPS A**: Export data from source ClickHouse server
- **Restore to VPS B**: Import data to destination ClickHouse server
- **Real-time Migration**: Set up continuous replication between servers
- **Emergency Migration**: Handle failing servers with large datasets (300GB+)

## Prerequisites

Before starting migration:
1. Both VPS instances have ClickHouse installed with TLS (see [quickstart](../quickstart/README.md))
2. Network connectivity between VPS A and VPS B on secure ports (9440, 8443)
3. Sufficient disk space for backups
4. Same ClickHouse version on both servers (recommended)
5. TLS certificates configured and valid on both servers

## Migration Strategies

### Strategy 1: Offline Migration (Downtime Required)

Best for: Small datasets (< 100GB), acceptable downtime

1. Stop writes to VPS A
2. Backup all data from VPS A
3. Transfer to VPS B
4. Restore on VPS B
5. Update application connections
6. Resume writes on VPS B

### Strategy 2: Online Migration (Minimal Downtime)

Best for: Large datasets, minimal downtime requirement

1. Set up real-time replication
2. Sync historical data
3. Switch to dual-write mode
4. Verify data consistency
5. Switch application to VPS B
6. Stop replication

### Strategy 3: Parallel Run (Zero Downtime)

Best for: Critical production systems

1. Set up replication from VPS A to VPS B
2. Run both systems in parallel
3. Gradually shift read traffic to VPS B
4. Switch write traffic to VPS B
5. Decommission VPS A

## Quick Start

### Backup from VPS A

```bash
# On VPS A
ssh user@vps-a
cd /path/to/clickhouse-test/02-data-migration/scripts
sudo ./backup-vps-a.sh
```

### Restore to VPS B

```bash
# On VPS B
ssh user@vps-b
cd /path/to/clickhouse-test/02-data-migration/scripts
sudo ./restore-vps-b.sh --source vps-a.example.com --backup-path /backup/clickhouse/
```

### Setup Real-time Replication

```bash
# On VPS B
sudo ./migrate-realtime.sh --source vps-a.example.com --mode setup
```

## Directory Structure

```
02-data-migration/
├── configs/
│   └── remote_servers.xml        # Cluster configuration template
├── examples/
│   ├── sample-table.sql          # Example table for testing
│   └── migration-workflow.md     # Detailed workflow examples
├── scripts/
│   ├── backup-vps-a.sh           # Standard backup script
│   ├── restore-vps-b.sh          # Standard restore script
│   ├── migrate-realtime.sh       # Real-time migration setup
│   └── emergency-migrate.sh      # Emergency migration for failing servers
├── EMERGENCY_MIGRATION.md        # Emergency migration strategies & procedures
├── STEP_BY_STEP_GUIDE.md         # Detailed step-by-step execution guide
└── README.md                     # This file
```

## Configuration

### Network Requirements

Ensure these ports are open between VPS A and VPS B:
- Port 9440 (native protocol with TLS) - **Required**
- Port 8443 (HTTPS with TLS) - **Required**

**Note:** Non-secure ports (9000, 8123) should be disabled or firewalled in production.

### TLS Prerequisites

Both servers must have:
1. Valid TLS certificates configured
2. Secure ports enabled (9440, 8443)
3. CA certificates available for verification

### User Permissions

Create a dedicated migration user on both servers:

```sql
-- On VPS A
CREATE USER migration_user IDENTIFIED WITH sha256_password BY 'secure_password';
GRANT ALL ON *.* TO migration_user;

-- On VPS B
CREATE USER migration_user IDENTIFIED WITH sha256_password BY 'secure_password';
GRANT ALL ON *.* TO migration_user;
```

## Backup Process

### What Gets Backed Up

1. **Database schemas** (CREATE TABLE statements)
2. **Table data** (exported as TSV or Native format)
3. **User definitions** (users, roles, quotas)
4. **Configuration files** (optional)
5. **Metadata** (partitions, mutations)

### Backup Formats

- **Native**: Binary format, fastest for ClickHouse-to-ClickHouse
- **TSV**: Text format, human-readable, larger size
- **Parquet**: Columnar format, good for analytics

### Backup Storage

Backups are stored in:
```
/backup/clickhouse/
├── schemas/           # Database and table schemas
├── data/              # Table data
├── users/             # User definitions
└── metadata/          # System metadata
```

## Restore Process

### Prerequisites Check

The restore script verifies:
1. ClickHouse is running on VPS B
2. Sufficient disk space available
3. No naming conflicts
4. Compatible ClickHouse versions

### Restore Steps

1. **Pre-restore validation**
   - Check disk space
   - Verify ClickHouse status
   - Validate backup integrity

2. **Schema restoration**
   - Create databases
   - Create tables with proper engine settings
   - Set up materialized views

3. **Data restoration**
   - Import data in optimal batch sizes
   - Verify row counts
   - Check data integrity

4. **Post-restore validation**
   - Compare row counts with source
   - Run sample queries
   - Verify permissions

## Real-time Migration

### Architecture

```
┌─────────┐         ┌─────────────────────────────────────┐
│  App    │────────→│ VPS A (Source)                      │
└─────────┘         │  ┌───────────────────────────────┐  │
                    │  │ ReplicatedMergeTree Engine    │  │
                    │  │ - Real-time data ingestion    │  │
                    │  └───────────────────────────────┘  │
                    └─────────────────────────────────────┘
                                      │
                                      │ Replication
                                      ▼
                    ┌─────────────────────────────────────┐
                    │ VPS B (Destination)                 │
                    │  ┌───────────────────────────────┐  │
                    │  │ ReplicatedMergeTree Engine    │  │
                    │  │ - Receives real-time updates  │  │
                    │  └───────────────────────────────┘  │
                    └─────────────────────────────────────┘
```

### Replication Setup

1. **Configure remote_servers.xml** on both VPS
2. **Create distributed tables** for cross-cluster queries
3. **Set up ReplicatedMergeTree** tables
4. **Initialize replication** with existing data
5. **Monitor replication lag**

### Monitoring

Track replication health:

```sql
-- Check replication status
SELECT *
FROM system.replication_queue
WHERE is_currently_executing = 1;

-- Check replication lag
SELECT 
    database,
    table,
    is_leader,
    total_replicas,
    active_replicas,
    zookeeper_path
FROM system.replicas;

-- Check parts to fetch
SELECT 
    database,
    table,
    type,
    count()
FROM system.replication_queue
GROUP BY database, table, type;
```

## Performance Considerations

### Backup Performance

- Use multi-threading for large tables
- Compress backups to reduce I/O
- Schedule backups during low-traffic hours
- Monitor disk I/O during backup

### Restore Performance

- Restore largest tables first
- Use max_insert_threads for parallel inserts
- Disable replication during initial load
- Consider materialized view recreation

### Network Transfer

- Use compression for network transfer
- Consider rsync for incremental transfers
- Use dedicated network link if available
- Monitor bandwidth usage

## Troubleshooting

### Common Issues

**Backup Failures:**
```bash
# Check disk space
df -h /backup/

# Check ClickHouse logs
sudo tail -f /var/log/clickhouse-server/clickhouse-server.log

# Verify permissions
ls -la /backup/clickhouse/
```

**Restore Failures:**
```bash
# Check if tables already exist
clickhouse-client -q "SHOW TABLES FROM database_name"

# Check for schema conflicts
clickhouse-client -q "SELECT name, engine FROM system.tables WHERE database = 'database_name'"

# Verify backup integrity
tar -tzf backup_file.tar.gz | head
```

**Replication Issues:**
```bash
# Check ZooKeeper connection
clickhouse-client -q "SELECT * FROM system.zookeeper WHERE path = '/'"

# Check replica status
clickhouse-client -q "SELECT * FROM system.replicas FORMAT Vertical"

# Check for errors
clickhouse-client -q "SELECT * FROM system.replication_queue WHERE last_exception != '' FORMAT Vertical"
```

## Security

### Data Protection

1. **Encrypt backups** at rest
2. **Use TLS** for data transfer
3. **Secure backup storage** with restricted access
4. **Audit migration** activities

### Access Control

1. Use dedicated migration user with limited privileges
2. Enable SSL/TLS for all connections
3. Restrict network access to migration ports
4. Log all migration activities

## Best Practices

1. **Test migration** on non-production data first
2. **Document** all custom configurations
3. **Monitor** resource usage during migration
4. **Validate** data integrity after migration
5. **Keep backups** until migration is verified
6. **Have rollback plan** ready

## Next Steps

After successful migration:
1. Update application connection strings
2. Configure monitoring for new server
3. Set up regular backups on VPS B
4. Decommission VPS A (if no longer needed)
5. Document any lessons learned

## Support

For issues or questions:
- Check ClickHouse logs: `/var/log/clickhouse-server/`
- Review system tables: `system.merges`, `system.replication_queue`
- Consult ClickHouse documentation: https://clickhouse.com/docs
