# ClickHouse Testing Architecture

## System Overview

This document describes the architecture for the ClickHouse testing environment, including TLS-secured deployment and data migration between VPS instances.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CLICKHOUSE TEST ARCHITECTURE                   │
└─────────────────────────────────────────────────────────────────────────┘

                              INTERNET
                                  │
                    ┌─────────────┴─────────────┐
                    │                             │
              HTTPS (8443)                  HTTPS (8443)
                    │                             │
           ┌────────▼────────┐          ┌────────▼────────┐
           │    Client A     │          │    Client B     │
           │   (Applications)│          │   (Monitoring)  │
           └────────┬────────┘          └────────┬────────┘
                    │                             │
           Native Secure (9440)          Native Secure (9440)
                    │                             │
     ╔══════════════╧═════════════════════════════╧══════════════╗
     ║                                                           ║
     ║  ┌─────────────────────────────────────────────────────┐  ║
     ║  │              VPS A (Source Server)                  │  ║
     ║  │  ┌───────────────────────────────────────────────┐  │  ║
     ║  │  │  ClickHouse Server                            │  │  ║
     ║  │  │  ┌─────────────────────────────────────────┐  │  │  ║
     ║  │  │  │  Config: config.xml (TLS enabled)       │  │  │  ║
     ║  │  │  │  Users: users.xml (secure passwords)    │  │  │  ║
     ║  │  │  │  Certs: server.crt, server.key, ca.crt  │  │  │  ║
     ║  │  │  └─────────────────────────────────────────┘  │  │  ║
     ║  │  └───────────────────────────────────────────────┘  │  ║
     ║  │                                                           │  ║
     ║  │  Data Storage: /var/lib/clickhouse/                       │  ║
     ║  │  - MergeTree Tables                                       │  ║
     ║  │  - ReplicatedMergeTree (optional)                         │  ║
     ║  └─────────────────────────────────────────────────────────┘  ║
     ║                            │                                  ║
     ║                            │ Data Migration                   ║
     ║                            │ (Replication / Backup-Restore)   ║
     ║                            ▼                                  ║
     ║  ┌─────────────────────────────────────────────────────────┐  ║
     ║  │              VPS B (Destination Server)                 │  ║
     ║  │  ┌───────────────────────────────────────────────┐  │  ║
     ║  │  │  ClickHouse Server                            │  │  ║
     ║  │  │  ┌─────────────────────────────────────────┐  │  │  ║
     ║  │  │  │  Config: config.xml (TLS enabled)       │  │  │  ║
     ║  │  │  │  Users: users.xml (secure passwords)    │  │  │  ║
     ║  │  │  │  Remote Servers: cluster definitions    │  │  │  ║
     ║  │  │  └─────────────────────────────────────────┘  │  │  ║
     ║  │  └───────────────────────────────────────────────┘  │  ║
     ║  │                                                           │  ║
     ║  │  Data Storage: /var/lib/clickhouse/                       │  ║
     ║  │  - Replicated tables from VPS A                           │  ║
     ║  │  - Local tables                                           │  ║
     ║  └─────────────────────────────────────────────────────────┘  ║
     ║                                                           ║
     ╚═══════════════════════════════════════════════════════════╝

```

## Component Details

### 1. VPS A (Source Server)

**Role:** Primary ClickHouse instance hosting production data

**Configuration:**
- **Operating System:** Ubuntu 20.04/22.04 LTS
- **ClickHouse Version:** Latest stable
- **TLS Configuration:**
  - HTTPS on port 8443
  - Native Secure on port 9440
  - TLS 1.2+ only
  - Strong cipher suites
- **Data Storage:** Local SSD storage for fast query performance
- **Replication:** Can act as replication source

**Key Files:**
- `/etc/clickhouse-server/config.xml` - Server configuration with TLS
- `/etc/clickhouse-server/users.xml` - User authentication and authorization
- `/etc/clickhouse-server/*.pem` - TLS certificates
- `/var/lib/clickhouse/` - Data directory

### 2. VPS B (Destination Server)

**Role:** Target server for migration and/or disaster recovery

**Configuration:**
- Mirror of VPS A configuration
- Receives data via replication or backup restore
- Can take over as primary after migration

**Key Features:**
- Remote server configurations for cross-cluster queries
- Distributed table support
- Real-time replication capabilities (with ZooKeeper)

### 3. Data Migration Layer

**Migration Methods:**

#### A. Backup and Restore (Offline Migration)
```
VPS A Data → Backup Archive → Transfer → Restore → VPS B Data
```

- **Tools:** `backup-vps-a.sh`, `restore-vps-b.sh`
- **Best for:** Small to medium datasets, planned maintenance windows
- **Speed:** Depends on data size and network bandwidth

#### B. Real-time Replication (Online Migration)
```
VPS A Write → Replication Queue → Network → VPS B Apply
```

- **Tools:** `migrate-realtime.sh`
- **Requirements:** ZooKeeper ensemble
- **Best for:** Large datasets, minimal downtime requirements
- **Consistency:** Eventual consistency with configurable lag

#### C. Distributed Tables (Hybrid Migration)
```
Application → Distributed Table → Routing → VPS A or VPS B
```

- **Best for:** Parallel run, gradual migration
- **Advantage:** Application sees single endpoint

## Network Architecture

### Port Configuration

| Port | Protocol | Description | Usage |
|------|----------|-------------|-------|
| 8123 | HTTP | Standard HTTP interface | Internal queries, monitoring |
| 8443 | HTTPS | Secure HTTP interface | External clients, production |
| 9000 | TCP | Native protocol | Internal applications |
| 9440 | TCP | Secure native protocol | External clients with TLS |
| 9009 | TCP | Inter-server communication | Replication, distributed queries |

### Security Zones

```
Internet (Untrusted)
    │
    ├── HTTPS (8443) ───→ WAF/Firewall ───→ ClickHouse HTTP Interface
    │
    └── Native Secure (9440) ───→ Firewall ───→ ClickHouse Native Interface

Internal Network (Trusted)
    │
    ├── HTTP (8123) ───→ Monitoring/Internal Tools
    │
    ├── Native (9000) ───→ Application Servers
    │
    └── Inter-server (9009) ───→ Replication between VPS A ↔ VPS B
```

## TLS/SSL Architecture

### Certificate Hierarchy

```
┌─────────────────────────────────────┐
│           Root CA                   │
│   (Self-signed or Organization CA)  │
└───────────────┬─────────────────────┘
                │
    ┌───────────┴───────────┐
    │                       │
┌───▼────┐            ┌────▼─────┐
│ VPS A  │            │  VPS B   │
│ Server │            │  Server  │
│ Cert   │            │  Cert    │
└────────┘            └──────────┘
```

### TLS Handshake Flow

1. **Client initiates connection** to VPS on port 9440
2. **Server presents certificate** (server.crt)
3. **Client validates certificate** against CA (ca.crt)
4. **TLS session established** with agreed cipher suite
5. **Encrypted communication** begins

### Supported Cipher Suites

- `ECDHE-RSA-AES256-GCM-SHA384`
- `ECDHE-RSA-AES128-GCM-SHA256`
- `DHE-RSA-AES256-GCM-SHA384`
- `DHE-RSA-AES128-GCM-SHA256`

## Data Flow Diagrams

### Query Flow

```
┌────────────┐     ┌──────────────────┐     ┌─────────────┐
│  Client    │────→│  Load Balancer   │────→│   VPS A     │
│  Query     │     │  (Optional)      │     │   Process   │
└────────────┘     └──────────────────┘     └──────┬──────┘
                                                   │
┌────────────┐     ┌──────────────────┐           │
│  Result    │←────│  Encrypted       │←──────────┘
│  Return    │     │  Response (TLS)  │
└────────────┘     └──────────────────┘
```

### Replication Flow (with ZooKeeper)

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Client    │────────→│   VPS A      │────────→│  ZooKeeper  │
│   Write     │         │   INSERT     │         │   /queue    │
└─────────────┘         └──────────────┘         └──────┬──────┘
                                                        │
┌─────────────┐         ┌──────────────┐               │
│   VPS B     │←────────│   Fetch      │←──────────────┘
│   Apply     │         │   Parts      │
└─────────────┘         └──────────────┘
```

### Backup Flow

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Backup     │────→│  Schema      │────→│  Archive    │
│  Trigger    │     │  Export      │     │  Creation   │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                │
┌─────────────┐     ┌──────────────┐           │
│  Storage    │←────│  Transfer    │←──────────┘
│  (VPS B)    │     │  (SCP/RSYNC) │
└─────────────┘     └──────────────┘
```

## High Availability Considerations

### Single Point of Failure Analysis

| Component | SPOF? | Mitigation |
|-----------|-------|------------|
| VPS A | Yes | VPS B as standby/replica |
| VPS B | Yes | VPS A as primary |
| Network | Yes | Multiple network paths |
| ZooKeeper | Yes | 3-node ensemble minimum |
| Certificates | Yes | Automated renewal, backup CA |

### Failover Scenarios

#### Scenario 1: VPS A Failure
```
1. Monitor detects VPS A unavailable
2. Promote VPS B to primary (if replication configured)
3. Update DNS/Load Balancer to point to VPS B
4. Alert administrators
5. Restore VPS A from backup when available
```

#### Scenario 2: Network Partition
```
1. Detect split-brain condition
2. Determine which side has most recent data
3. Manually intervene to choose primary
4. Reconcile data when partition heals
```

## Monitoring Architecture

### Metrics Collection

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   VPS A      │     │  Prometheus  │     │  Grafana     │
│  Exporter    │────→│   Server     │────→│ Dashboards   │
└──────────────┘     └──────────────┘     └──────────────┘
                           │
┌──────────────┐           │               ┌──────────────┐
│   VPS B      │───────────┘               │  Alert       │
│  Exporter    │                           │  Manager     │
└──────────────┘                           └──────────────┘
```

### Key Metrics to Monitor

- **Query Performance:** Queries per second, execution time, errors
- **Replication Lag:** Seconds behind source, queue depth
- **Resource Usage:** CPU, memory, disk I/O, network
- **TLS Metrics:** Handshake failures, certificate expiration
- **Storage:** Part count, merge speed, free space

## Scaling Considerations

### Vertical Scaling (Scale Up)

```
Current: 4 CPU, 16GB RAM, 500GB SSD
Target:  8 CPU, 32GB RAM, 1TB SSD

Method: Resize VPS instance
Downtime: Required (minutes)
Risk: Low
```

### Horizontal Scaling (Scale Out)

```
Current: Single VPS
Target:  Multi-shard cluster

Method: Add VPS C, VPS D, shard data
Downtime: Minimal (with distributed tables)
Risk: Medium (data sharding complexity)
```

## Security Architecture

### Defense in Depth

```
Layer 1: Network Security
├── Firewall rules (ports 8443, 9440 only)
├── VPC/Private network isolation
└── DDoS protection

Layer 2: Transport Security
├── TLS 1.2+ encryption
├── Certificate pinning
└── Cipher suite restrictions

Layer 3: Authentication
├── Strong password policies
├── Certificate-based auth
└── Network-based access control

Layer 4: Authorization
├── Role-based access control (RBAC)
├── Database/table-level permissions
└── Row-level security (optional)

Layer 5: Audit
├── Query logging
├── Access logs
└── Change tracking
```

## Disaster Recovery

### RPO/RTO Targets

| Scenario | RPO (Data Loss) | RTO (Downtime) |
|----------|----------------|----------------|
| Replication | < 1 second | < 5 minutes |
| Hourly Backup | < 1 hour | < 1 hour |
| Daily Backup | < 24 hours | < 4 hours |

### Recovery Procedures

1. **Point-in-Time Recovery:**
   ```
   Last Full Backup + Binary Logs + Time
   ```

2. **Cross-Region Recovery:**
   ```
   Primary Region (VPS A) → DR Region (VPS B)
   ```

3. **Complete Rebuild:**
   ```
   New VPS → Install ClickHouse → Restore from Backup → Verify
   ```

## Best Practices Summary

1. **Always use TLS** for external connections
2. **Regular backups** with automated verification
3. **Monitor replication lag** and set alerts
4. **Test failover procedures** regularly
5. **Keep configurations in version control**
6. **Use strong authentication** and rotate credentials
7. **Limit network exposure** with firewall rules
8. **Document all changes** and maintain runbooks

## References

- [ClickHouse Documentation](https://clickhouse.com/docs)
- [ClickHouse Replication Guide](https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/replication)
- [TLS Configuration Best Practices](https://clickhouse.com/docs/en/operations/server-configuration-parameters/settings#openssl)
- [ClickHouse Monitoring Guide](https://clickhouse.com/docs/en/operations/monitoring)
