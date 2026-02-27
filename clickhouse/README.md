# ClickHouse Testing Project

A comprehensive testing environment for ClickHouse deployment with TLS security and data migration capabilities.

## Project Structure

```
clickhouse/
├── quickstart/               # VPS setup with TLS configuration (Official Guide)
│   ├── configs/              # ClickHouse configuration files
│   │   └── config.d/         # Modular configuration (SSL, ACME)
│   ├── scripts/              # Installation and certificate scripts
│   └── certs/                # TLS certificates directory
├── 02-data-migration/        # Data migration between VPS instances
│   ├── configs/              # Cluster configuration
│   ├── examples/             # Example migration scenarios
│   └── scripts/              # Migration scripts
├── docs/                     # Documentation
└── README.md                # This file
```

## Quick Start

1. **Setup TLS Configuration**: Follow instructions in `quickstart/README.md`
2. **Configure Data Migration**: Follow instructions in `02-data-migration/README.md`
3. **Review Architecture**: See `docs/architecture.md` for system overview

## Components

### quickstart
Production-ready ClickHouse installation following official documentation:
- TLS/SSL encryption (OpenSSL configuration)
- Certificate generation (CA + Server certificates)
- ACME automatic certificate provisioning (Let's Encrypt)
- Modular configuration (config.d/ structure)
- Secure client connections

### 02-data-migration
Comprehensive migration toolkit including:
- Backup and restore scripts
- Real-time replication setup
- Cluster configuration
- Migration examples

## Requirements

- Ubuntu 20.04+ or Debian 11+
- Root or sudo access
- Domain name (optional, for ACME/Let's Encrypt)
- Minimum 4GB RAM
- 20GB free disk space
- Open ports: 8443 (HTTPS), 9440 (Native Secure), 80 (ACME only)

## Security Considerations

This project implements production-grade security measures:
- TLS 1.2+ encryption (SSLv2, SSLv3 disabled)
- Self-signed or CA-signed certificates
- Certificate verification modes
- Strong cipher suites
- Secure client connections (--secure flag)

## License

MIT License - See LICENSE file for details
