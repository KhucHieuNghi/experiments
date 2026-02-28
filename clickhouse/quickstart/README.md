# ClickHouse Quick Start with TLS

This guide provides minimal settings to configure ClickHouse to use OpenSSL certificates for secure connections.

**Note:** TLS implementation is complex with many options. This is a basic tutorial with minimal TLS configuration examples. Consult your security team for production certificates.

## Table of Contents

1. [Create ClickHouse Deployment](#1-create-clickhouse-deployment)
2. [Create TLS Certificates](#2-create-tls-certificates)
3. [Configure Certificate Directory](#3-configure-certificate-directory)
4. [Configure TLS Interfaces](#4-configure-tls-interfaces)
5. [Testing](#5-testing)
6. [ACME Automatic TLS](#6-acme-automatic-tls-optional)

---

## 1. Create ClickHouse Deployment

### Prerequisites

- Ubuntu 20.04+ or Debian 11+
- Root or sudo privileges
- Domain name pointing to your server (optional but recommended)
- Open ports: 8443 (HTTPS), 9440 (Native Secure)

### Installation

#### Option A: Quick Install (For Testing/Development)

ClickHouse runs natively on Linux, FreeBSD and macOS, and runs on Windows via the WSL. The simplest way to download ClickHouse locally is to run the following curl command. It determines if your operating system is supported, then downloads an appropriate ClickHouse binary.

> **Note:** We recommend running the command below from a new and empty subdirectory as some configuration files will be created in the directory the binary is located in the first time ClickHouse server is run. This script isn't the recommended way to install ClickHouse for production.

```bash
curl https://clickhouse.com/ | sh
```

You should see output similar to:
```text
Successfully downloaded the ClickHouse binary, you can run it as:
    ./clickhouse

You can also install it:
sudo ./clickhouse install
```

At this stage, you can ignore the prompt to run the install command.

> **Note for Mac users:** If you're getting errors that the developer of the binary can't be verified, please see "Fix the Developer Verification Error in MacOS".

Start the server:
```bash
./clickhouse server
```

Start the client in a new terminal:
```bash
./clickhouse client
```

#### Option B: DEB Package Installation (Production)

Install ClickHouse using the official DEB package:

```bash
# Update system
sudo apt-get update

# Install dependencies
sudo apt-get install -y apt-transport-https ca-certificates dirmngr gnupg curl

# Add ClickHouse repository
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8919F6BD2B48D754
echo "deb https://packages.clickhouse.com/deb stable main" | sudo tee /etc/apt/sources.list.d/clickhouse.list

# Install ClickHouse
sudo apt-get update
sudo apt-get install -y clickhouse-server clickhouse-client

# Start service
sudo systemctl enable clickhouse-server
sudo systemctl start clickhouse-server
```

---

## 2. Create TLS Certificates

**Note:** Self-signed certificates are for demonstration only. Use certificates signed by your organization's CA for production.

### Generate CA Certificate

Create the Certificate Authority (CA) that will sign server certificates:

```bash
cd /etc/clickhouse-server

# Generate CA key
sudo openssl genrsa -out marsnet_ca.key 2048

# Generate self-signed CA certificate
sudo openssl req -x509 -subj "/CN=marsnet.local CA" -nodes \
  -key marsnet_ca.key -days 1095 -out marsnet_ca.crt

# Verify CA certificate
sudo openssl x509 -in marsnet_ca.crt -text
```

**Important:** Backup `marsnet_ca.key` and `marsnet_ca.crt` in a secure location NOT on the server.

### Generate Server Certificate

Replace `your-domain.com` and `YOUR_SERVER_IP` with your actual values:

```bash
# Create certificate request and key
sudo openssl req -newkey rsa:2048 -nodes \
  -subj "/CN=your-server" \
  -addext "subjectAltName = DNS:your-domain.com,IP:YOUR_SERVER_IP" \
  -keyout server.key -out server.csr

# Sign with CA
sudo openssl x509 -req -in server.csr -out server.crt \
  -CA marsnet_ca.crt -CAkey marsnet_ca.key -days 365 -copy_extensions copy

# Verify certificate
sudo openssl x509 -in server.crt -text -noout
sudo openssl verify -CAfile marsnet_ca.crt server.crt
```

---

## 3. Configure Certificate Directory

Create secure directory for certificates:

```bash
# Create certs directory
sudo mkdir -p /etc/clickhouse-server/certs

# Copy certificates (if not already there)
sudo cp marsnet_ca.crt server.crt server.key /etc/clickhouse-server/certs/

# Set ownership and permissions
sudo chown clickhouse:clickhouse -R /etc/clickhouse-server/certs
sudo chmod 600 /etc/clickhouse-server/certs/*
sudo chmod 755 /etc/clickhouse-server/certs

# Verify permissions
ls -la /etc/clickhouse-server/certs/
```

**Cleanup:** Delete `marsnet_ca.key` from the server after generating certificates:
```bash
sudo rm /etc/clickhouse-server/marsnet_ca.key
```

---

## 4. Configure TLS Interfaces

### Create config.d directory structure

```bash
sudo mkdir -p /etc/clickhouse-server/config.d
```

### SSL Configuration

Create `/etc/clickhouse-server/config.d/ssl.xml`:

```xml
<clickhouse>
    <!-- HTTPS Port -->
    <https_port>8443</https_port>
    <!-- Disable HTTP -->
    <!--<http_port>8123</http_port>-->

    <!-- Native Secure TCP Port -->
    <tcp_port_secure>9440</tcp_port_secure>
    <!-- Disable default native port -->
    <!--<tcp_port>9000</tcp_port>-->

    <!-- Interserver HTTPS (for replication) -->
    <interserver_https_port>9010</interserver_https_port>
    <!--<interserver_http_port>9009</interserver_http_port>-->

    <!-- Listen on all interfaces -->
    <listen_host>0.0.0.0</listen_host>

    <!-- OpenSSL Configuration -->
    <openSSL>
        <server>
            <certificateFile>/etc/clickhouse-server/certs/server.crt</certificateFile>
            <privateKeyFile>/etc/clickhouse-server/certs/server.key</privateKeyFile>
            <verificationMode>relaxed</verificationMode>
            <caConfig>/etc/clickhouse-server/certs/marsnet_ca.crt</caConfig>
            <cacheSessions>true</cacheSessions>
            <disableProtocols>sslv2,sslv3</disableProtocols>
            <preferServerCiphers>true</preferServerCiphers>
        </server>
        <client>
            <loadDefaultCAFile>false</loadDefaultCAFile>
            <caConfig>/etc/clickhouse-server/certs/marsnet_ca.crt</caConfig>
            <cacheSessions>true</cacheSessions>
            <disableProtocols>sslv2,sslv3</disableProtocols>
            <preferServerCiphers>true</preferServerCiphers>
            <verificationMode>relaxed</verificationMode>
            <invalidCertificateHandler>
                <name>RejectCertificateHandler</name>
            </invalidCertificateHandler>
        </client>
    </openSSL>

    <!-- Disable MySQL and PostgreSQL emulation ports -->
    <!--<mysql_port>9004</mysql_port>-->
    <!--<postgresql_port>9005</postgresql_port>-->
</clickhouse>
```

### Client Configuration

Create client config at `/etc/clickhouse-client/config.xml`:

```xml
<config>
    <openSSL>
        <client>
            <loadDefaultCAFile>false</loadDefaultCAFile>
            <caConfig>/etc/clickhouse-server/certs/marsnet_ca.crt</caConfig>
            <cacheSessions>true</cacheSessions>
            <disableProtocols>sslv2,sslv3</disableProtocols>
            <preferServerCiphers>true</preferServerCiphers>
            <invalidCertificateHandler>
                <name>RejectCertificateHandler</name>
            </invalidCertificateHandler>
        </client>
    </openSSL>
</config>
```

### Apply Configuration

```bash
# Set ownership
sudo chown -R clickhouse:clickhouse /etc/clickhouse-server/

# Restart ClickHouse
sudo systemctl restart clickhouse-server

# Check status
sudo systemctl status clickhouse-server
```

---

## 5. Testing

### Verify Ports

```bash
sudo netstat -tlnp | grep clickhouse
# or
sudo ss -tlnp | grep clickhouse
```

You should see:
- `0.0.0.0:8443` - HTTPS interface
- `0.0.0.0:9440` - Native secure protocol
- `0.0.0.0:9010` - Interserver HTTPS (if configured)

### Test HTTPS Connection

```bash
# Test ping endpoint
curl -k https://localhost:8443/ping

# Check certificate info
openssl s_client -connect localhost:8443 </dev/null 2>/dev/null | openssl x509 -noout -text
```

### Test Native Secure Connection

```bash
# Connect with secure flag
clickhouse-client --secure --port 9440

# Or with host
clickhouse-client --secure --port 9440 --host your-domain.com

# Test query
SELECT 1;
```

### Test via Play UI

Open browser and navigate to:
```
https://your-domain.com:8443/play
```

**Note:** Browser will show "untrusted certificate" warning for self-signed certs. This is expected.

### Create Test Table

```sql
-- Create database
CREATE DATABASE IF NOT EXISTS test;

-- Create table
CREATE TABLE test.sample_table (
    id UInt64,
    name String,
    created_at DateTime
) ENGINE = MergeTree()
ORDER BY id;

-- Insert data
INSERT INTO test.sample_table VALUES
(1, 'Test 1', now()),
(2, 'Test 2', now());

-- Query data
SELECT * FROM test.sample_table;
```

---

## 6. ACME Automatic TLS (Optional)

For automatic certificate provisioning via Let's Encrypt or ZeroSSL:

### Requirements

- Domain name pointing to your server
- Port 80 available for ACME HTTP-01 challenge
- Email address for ACME account

### Configuration

Create `/etc/clickhouse-server/config.d/acme.xml`:

```xml
<clickhouse>
    <!-- HTTP port for ACME challenge -->
    <http_port>80</http_port>
    <!-- HTTPS port for encrypted traffic -->
    <https_port>443</https_port>

    <acme>
        <email>your-email@example.com</email>
        <terms_of_service_agreed>true</terms_of_service_agreed>
        <domains>
            <domain>your-domain.com</domain>
        </domains>
        <!-- Optional: Use staging for testing -->
        <!--<directory_url>https://acme-staging-v02.api.letsencrypt.org/directory</directory_url>-->
    </acme>
</clickhouse>
```

### ACME Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `directory_url` | `https://acme-v02.api.letsencrypt.org/directory` | ACME directory endpoint |
| `email` | - | Email for ACME account |
| `terms_of_service_agreed` | false | Accept ACME terms |
| `domains` | - | List of domains for certificates |
| `refresh_certificates_before` | 2592000 (30 days) | Renew before expiration |
| `refresh_certificates_task_interval` | 3600 (1 hour) | Check interval |

### Testing ACME

1. **Start with staging:** Uncomment staging URL to test without rate limits
2. **Verify domain:** Ensure port 80 is accessible from internet
3. **Check logs:** Monitor `/var/log/clickhouse-server/clickhouse-server.log`
4. **Production:** Switch to production URL after successful staging test

---

## Troubleshooting

### Certificate Errors

```bash
# Check certificate validity
sudo openssl x509 -in /etc/clickhouse-server/certs/server.crt -noout -dates

# Test TLS handshake
openssl s_client -connect localhost:8443 -showcerts

# Verify permissions
ls -la /etc/clickhouse-server/certs/
```

### Connection Issues

```bash
# Check if ClickHouse is listening
sudo netstat -tlnp | grep -E '8443|9440'

# Review configuration
sudo clickhouse-server --config-file=/etc/clickhouse-server/config.xml --config-check

# Check logs
sudo tail -f /var/log/clickhouse-server/clickhouse-server.log
```

### Permission Problems

```bash
# Fix ownership
sudo chown -R clickhouse:clickhouse /etc/clickhouse-server/
sudo chown -R clickhouse:clickhouse /var/lib/clickhouse/
sudo chown -R clickhouse:clickhouse /var/log/clickhouse-server/

# Restart
sudo systemctl restart clickhouse-server
```

---

## Next Steps

Once TLS is configured, proceed to [02-data-migration](../02-data-migration/README.md) for data migration between VPS instances.

## References

- [ClickHouse TLS Documentation](https://clickhouse.com/docs/en/guides/sre/configuring-ssl)
- [ClickHouse ACME Documentation](https://clickhouse.com/docs/en/operations/server-configuration-parameters/settings#acme)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
