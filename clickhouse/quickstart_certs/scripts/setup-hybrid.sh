#!/bin/bash

# Quick setup script for ClickHouse Hybrid Architecture
# Script cài đặt nhanh cho kiến trúc Hybrid ClickHouse

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ClickHouse Hybrid Architecture Setup ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Please run as root (use sudo)${NC}"
    exit 1
fi

# Get domain name
if [ -z "$1" ]; then
    echo -n "Enter your domain (e.g., ch.domain.com): "
    read DOMAIN
else
    DOMAIN=$1
fi

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Domain is required${NC}"
    exit 1
fi

echo -e "${YELLOW}Setting up for domain: $DOMAIN${NC}"

# Step 1: System recovery
echo -e "${GREEN}[1/6] System Recovery...${NC}"
systemctl stop clickhouse-server 2>/dev/null || true
killall -9 clickhouse-server 2>/dev/null || true
rm -f /var/lib/clickhouse/status 2>/dev/null || true

# Step 2: Install dependencies
echo -e "${GREEN}[2/6] Installing dependencies...${NC}"
apt-get update
apt-get install -y ufw certbot curl docker-compose

# Step 3: Configure firewall
echo -e "${GREEN}[3/6] Configuring firewall...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 8443/tcp
ufw allow 9440/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw deny 8123/tcp
ufw deny 9000/tcp
ufw --force enable

# Step 4: Get SSL certificate
echo -e "${GREEN}[4/6] Obtaining SSL certificate...${NC}"
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    certbot certonly --standalone -d $DOMAIN --agree-tos -n --email admin@$DOMAIN 2>/dev/null || \
    certbot certonly --standalone -d $DOMAIN --agree-tos
fi

# Step 5: Setup Nginx container
echo -e "${GREEN}[5/6] Setting up Nginx container...${NC}"
mkdir -p /opt/nginx-proxy/conf.d
mkdir -p /opt/nginx-proxy/nginx-logs

# Copy docker-compose
cp docker-compose.yml /opt/nginx-proxy/ 2>/dev/null || \
curl -o /opt/nginx-proxy/docker-compose.yml \
    https://raw.githubusercontent.com/ClickHouse/ClickHouse/master/docker/compose/nginx/docker-compose.yml

# Create nginx config with domain
cat > /opt/nginx-proxy/conf.d/clickhouse.conf << EOF
upstream clickhouse_backend {
    server 127.0.0.1:8123;
    keepalive 32;
}

server {
    listen 8443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://clickhouse_backend/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 3600;
    }
}
EOF

# Start Nginx
cd /opt/nginx-proxy
docker-compose down 2>/dev/null || true
docker-compose up -d

# Step 6: Configure ClickHouse
echo -e "${GREEN}[6/6] Configuring ClickHouse...${NC}"
mkdir -p /etc/clickhouse-server/config.d

cat > /etc/clickhouse-server/config.d/network.xml << EOF
<clickhouse>
    <listen_host>0.0.0.0</listen_host>
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <tcp_port_secure>9440</tcp_port_secure>
    
    <openSSL>
        <server>
            <certificateFile>/etc/letsencrypt/live/$DOMAIN/fullchain.pem</certificateFile>
            <privateKeyFile>/etc/letsencrypt/live/$DOMAIN/privkey.pem</privateKeyFile>
            <verificationMode>relaxed</verificationMode>
        </server>
    </openSSL>

    <networks>
        <ip>127.0.0.1</ip>
        <ip>::1</ip>
    </networks>
</clickhouse>
EOF

# Fix permissions
chown -R clickhouse:clickhouse /var/lib/clickhouse
chown -R clickhouse:clickhouse /etc/clickhouse-server

# Start ClickHouse
systemctl enable clickhouse-server
systemctl start clickhouse-server

# Wait for ClickHouse to start
sleep 3

# Test connection
echo ""
echo -e "${GREEN}=== Testing connections ===${NC}"

if curl -s http://127.0.0.1:8123/ping | grep -q "Ok"; then
    echo -e "${GREEN}✓ ClickHouse HTTP (local): OK${NC}"
else
    echo -e "${YELLOW}✗ ClickHouse HTTP (local): Failed${NC}"
fi

if curl -s -k https://127.0.0.1:8443/ping 2>/dev/null | grep -q "Ok"; then
    echo -e "${GREEN}✓ Nginx HTTPS: OK${NC}"
else
    echo -e "${YELLOW}✗ Nginx HTTPS: Failed (may need domain setup)${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Domain: $DOMAIN"
echo "HTTPS Port: 8443 (via Nginx)"
echo "Native Secure Port: 9440"
echo ""
echo "Next steps:"
echo "1. Configure DNS for $DOMAIN to point to this server"
echo "2. Set up Cloudflare with Full (Strict) SSL mode"
echo "3. Test connection: curl https://$DOMAIN:8443/ping"
echo "4. Connect with DataGrip: Host=$DOMAIN, Port=8443, SSL=Yes"
