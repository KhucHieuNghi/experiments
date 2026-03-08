# ClickHouse Master Setup Guide

**Tài liệu hướng dẫn cài đặt ClickHouse toàn diện** | **Comprehensive ClickHouse Installation Guide**

Tài liệu này cung cấp quy trình hoàn chỉnh để khôi phục ClickHouse, cấu hình SSL/TLS chuyên nghiệp cho domain và triển khai kiến trúc lai (Hybrid) tối ưu cho hệ thống lớn.

This document provides a complete workflow for ClickHouse recovery, professional SSL/TLS configuration for domains, and deployment of an optimized Hybrid architecture for large-scale systems.

---

## Mục lục | Table of Contents

1. [Dọn dẹp và Khôi phục Hệ thống (System Recovery)](#1-dọn-dẹp-và-khôi-phục-hệ-thống)
2. [Cấu hình ClickHouse Trực tiếp (Direct Install)](#2-cấu-hình-clickhouse-trực-tiếp)
3. [Lớp Tường lửa (Firewall Security)](#3-lớp-tường-lửa)
4. [Kiến trúc Lai: Nginx trong Container (Hybrid Architecture)](#4-kiến-trúc-lai)
5. [Bảo mật với Certbot (Let's Encrypt)](#5-bảo-mật-với-certbot)
6. [Hướng dẫn cấu hình trên Cloudflare](#6-cloudflare-configuration)
7. [Sơ đồ Luồng Hoạt động](#7-sơ-đồ-luồng-hoạt-động)
8. [Tinh chỉnh Hiệu năng & Xác minh](#8-tinh-chỉnh-hiệu-năng)
9. [Kết nối Client](#9-kết-nối-client)

---

## 1. Dọn dẹp và Khôi phục Hệ thống

Trước khi cấu hình mới, phải giải quyết các xung đột tiến trình và file lock cũ.

**Before new configuration, resolve process conflicts and old lock files.**

```bash
# 1. Dừng service và xóa tiến trình chạy ngầm
# Stop service and kill background processes
sudo systemctl stop clickhouse-server
sudo killall -9 clickhouse-server || true

# 2. Xóa file lock (Lỗi Code 76)
# Remove lock files (Error Code 76)
sudo rm -f /var/lib/clickhouse/status

# 3. Phân quyền lại thư mục dữ liệu cho user clickhouse
# Fix ownership for clickhouse user
sudo chown -R clickhouse:clickhouse /var/lib/clickhouse
sudo chown -R clickhouse:clickhouse /etc/clickhouse-server
```

---

## 2. Cấu hình ClickHouse Trực tiếp

Để đạt hiệu năng I/O tối đa, ClickHouse được cài đặt trực tiếp trên OS. Chúng ta sẽ giới hạn các cổng không bảo mật chỉ chạy nội bộ.

**For maximum I/O performance, ClickHouse is installed directly on the OS. We will restrict insecure ports to localhost only.**

### Cấu hình XML (/etc/clickhouse-server/config.d/network.xml)

```xml
<clickhouse>
    <!-- Lắng nghe trên tất cả interface cho các cổng bảo mật -->
    <!-- Listen on all interfaces for secure ports -->
    <listen_host>0.0.0.0</listen_host>

    <!-- CHỈ cho phép truy cập nội bộ (localhost) cho các cổng không bảo mật -->
    <!-- Internal access only for insecure ports -->
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    
    <!-- Cổng Native Secure mở ra ngoài cho App (Yêu cầu TLS) -->
    <!-- Native Secure port open for apps (TLS required) -->
    <tcp_port_secure>9440</tcp_port_secure>
    
    <openSSL>
        <server>
            <certificateFile>/etc/letsencrypt/live/ch.domain.com/fullchain.pem</certificateFile>
            <privateKeyFile>/etc/letsencrypt/live/ch.domain.com/privkey.pem</privateKeyFile>
            <verificationMode>relaxed</verificationMode>
        </server>
    </openSSL>

    <!-- Bổ sung: Chặn truy cập HTTP/TCP không bảo mật từ bên ngoài ở tầng ứng dụng -->
    <networks>
        <ip>127.0.0.1</ip>
        <ip>::1</ip>
        <!-- Thêm dải IP mạng nội bộ nếu cần thiết -->
        <!-- <ip>10.0.0.0/8</ip> -->
    </networks>
</clickhouse>
```

> **Lưu ý**: Thay `ch.domain.com` bằng domain của bạn. | **Note**: Replace `ch.domain.com` with your actual domain.

---

## 3. Lớp Tường lửa

Sử dụng UFW để chặn truy cập trực tiếp qua IP vào các cổng không an toàn.

**Use UFW to block direct IP access to insecure ports.**

```bash
# 1. Cài đặt UFW (nếu chưa có)
# Install UFW if not present
sudo apt install ufw -y

# 2. Thiết lập chính sách mặc định
# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 3. Cho phép SSH (Quan trọng để không bị khóa máy)
# Allow SSH (IMPORTANT to avoid locking yourself out)
sudo ufw allow ssh

# 4. Chỉ cho phép các cổng bảo mật từ bên ngoài
# Allow only secure ports from outside
sudo ufw allow 8443/tcp  # HTTPS (Nginx Container)
sudo ufw allow 9440/tcp  # Native Secure (ClickHouse Direct)
sudo ufw allow 80/tcp    # HTTP (Cho Certbot xác thực)
sudo ufw allow 443/tcp   # HTTPS tiêu chuẩn

# 5. Chặn cổng 8123 và 9000 từ bên ngoài
# Deny insecure ports from outside
sudo ufw deny 8123/tcp
sudo ufw deny 9000/tcp

# 6. Kích hoạt tường lửa
# Enable firewall
sudo ufw enable

# Kiểm tra trạng thái
# Check status
sudo ufw status verbose
```

---

## 4. Kiến trúc Lai: Nginx trong Container

### Docker Compose (/opt/nginx-proxy/docker-compose.yml)

```yaml
version: '3.8'
services:
  nginx:
    image: nginx:latest
    container_name: nginx-clickhouse
    network_mode: "host"
    volumes:
      - ./conf.d:/etc/nginx/conf.d
      - /etc/letsencrypt:/etc/letsencrypt:ro
    restart: always
```

### Nginx Config (./conf.d/clickhouse.conf)

```nginx
server {
    listen 8443 ssl;
    server_name ch.domain.com;

    ssl_certificate /etc/letsencrypt/live/ch.domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ch.domain.com/privkey.pem;

    # Cấu hình bảo mật bổ sung
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    
    location / {
        proxy_pass http://127.0.0.1:8123;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600;
        proxy_connect_timeout 60;
        proxy_send_timeout 60;
    }
}
```

### Triển khai Nginx | Deploy Nginx

```bash
# Tạo thư mục và copy config
# Create directory and copy config
sudo mkdir -p /opt/nginx-proxy/conf.d
sudo cp configs/nginx/clickhouse.conf /opt/nginx-proxy/conf.d/

# Khởi động container
# Start container
cd /opt/nginx-proxy
sudo docker-compose up -d

# Kiểm tra logs
# Check logs
sudo docker-compose logs -f
```

---

## 5. Bảo mật với Certbot

```bash
# Cài đặt Certbot
# Install Certbot
sudo apt install certbot -y

# Lấy chứng chỉ (Yêu cầu port 80 đang mở)
# Obtain certificate (requires port 80 open)
sudo certbot certonly --standalone -d ch.domain.com

# Tự động gia hạn (cron job đã được tạo tự động)
# Auto-renewal (cron job created automatically)

# Kiểm tra gia hạn
# Test renewal
sudo certbot renew --dry-run
```

---

## 6. Hướng dẫn cấu hình trên Cloudflare

Để đảm bảo hệ thống `ch.domain.com` hoạt động an toàn nhất qua Cloudflare:

**To ensure your system operates securely through Cloudflare:**

### A. Thiết lập DNS | DNS Setup

- **Bản ghi A**: Tên `ch` trỏ về IP server của bạn (ví dụ: `225.85.25.39`)
- **A Record**: Name `ch` points to your server IP (e.g., `225.85.25.39`)

| Chế độ Proxy | Sử dụng | Mode | Usage |
|-------------|---------|------|-------|
| **Proxy (Orange Cloud)** | DataGrip/Web qua Port 8443 | DataGrip/Web via Port 8443 |
| **DNS Only (Gray Cloud)** | Native TCP Port 9440 nếu gặp lỗi | Native TCP Port 9440 if errors occur |

> **Lưu ý**: Cloudflare Spectrum (cho TCP) yêu cầu gói Pro/Business
> **Note**: Cloudflare Spectrum (for TCP) requires Pro/Business plan

### B. Thiết lập SSL/TLS (Tab SSL/TLS)

| Cài đặt | Giá trị | Setting | Value |
|---------|---------|---------|-------|
| Chế độ mã hóa | **Full (Strict)** | Encryption Mode | **Full (Strict)** |
| Always Use HTTPS | **BẬT** | Always Use HTTPS | **ON** |
| Minimum TLS Version | **TLS 1.2** | Minimum TLS Version | **TLS 1.2** |

### C. Firewall Rules (Tab Security → WAF)

Tạo rule để:
- Chỉ cho phép truy cập từ các quốc gia/IP mong muốn
- Chặn các request có User-Agent lạ
- Chặn các truy vấn dạng brute-force

**Create rules to:**
- Allow access only from desired countries/IPs
- Block requests with unusual User-Agents
- Block brute-force queries

---

## 7. Sơ đồ Luồng Hoạt động

```
[ Client ] 
    |
    v (HTTPS / TLS)
[ Cloudflare (Full Strict + WAF) ]
    |
    v (Chỉ cho phép Port 8443, 9440)
[ VPS Firewall (UFW) ] 
    |
    +--- (Port 8443) ---> [ Nginx Docker ] --- (Local:8123) ---> [ ClickHouse ]
    |
    +--- (Port 9440) ---------------- (Native TLS) ----------> [ ClickHouse ]
```

### Luồng HTTPS (Web/DataGrip) | HTTPS Flow

```
Client → Cloudflare (WAF) → UFW:8443 → Nginx:8443 → ClickHouse:8123
```

### Luồng Native TCP (Applications) | Native TCP Flow

```
Client → Cloudflare (nếu Spectrum) → UFW:9440 → ClickHouse:9440 (Native TLS)
```

---

## 8. Tinh chỉnh Hiệu năng & Xác minh

### Tinh chỉnh Linux | Linux Tuning

```bash
# Bật hiệu năng CPU tối đa
# Enable maximum CPU performance
echo 'performance' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Tăng limits hệ thống
# Increase system limits
echo '* soft nofile 262144' | sudo tee -a /etc/security/limits.conf
echo '* hard nofile 262144' | sudo tee -a /etc/security/limits.conf

# Tinh chỉnh kernel cho ClickHouse
# Kernel tuning for ClickHouse
echo 'vm.overcommit_memory = 1' | sudo tee -a /etc/sysctl.conf
echo 'vm.swappiness = 10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Xác minh kết nối | Verify Connections

```bash
# 1. Thử truy cập trực tiếp IP (8123) - PHẢI THẤT BẠI
# Try direct IP access (8123) - MUST FAIL
# curl http://YOUR_IP:8123/ping

# 2. Thử qua Domain (8443) - PHẢI TRẢ VỀ "Ok."
# Try via Domain (8443) - MUST RETURN "Ok."
curl https://ch.domain.com:8443/ping

# 3. Kiểm tra kết nối TLS bảo mật
# Check secure TLS connection
curl --cacert /etc/letsencrypt/live/ch.domain.com/chain.pem \
     https://ch.domain.com:8443/ping

# 4. Kiểm tra port 9440 (Native Secure)
# Check port 9440 (Native Secure)
openssl s_client -connect ch.domain.com:9440
```

---

## 9. Kết nối Client

### DataGrip / DBeaver

| Tham số | Giá trị | Parameter | Value |
|---------|---------|-----------|-------|
| Host | `ch.domain.com` | Host | `ch.domain.com` |
| Port | `8443` | Port | `8443` |
| SSL | **Tích chọn "Use SSL"** | SSL | **Enable "Use SSL"** |
| URL | `https://ch.domain.com:8443` | URL | `https://ch.domain.com:8443` |

> **Lưu ý**: Không cần file CA vì Certbot được tin cậy mặc định.
> **Note**: No CA file needed as Certbot is trusted by default.

### clickhouse-client

```bash
# Kết nối qua HTTP (qua Nginx)
# Connect via HTTP (through Nginx)
clickhouse-client --host ch.domain.com --port 8443 --secure

# Kết nối qua Native TCP (trực tiếp)
# Connect via Native TCP (direct)
clickhouse-client --host ch.domain.com --port 9440 --secure

# Với username/password
# With username/password
clickhouse-client --host ch.domain.com --port 9440 --secure \
    --user admin --password YOUR_PASSWORD
```

### Python (clickhouse-connect)

```python
import clickhouse_connect

client = clickhouse_connect.get_client(
    host='ch.domain.com',
    port=8443,
    username='admin',
    password='your_password',
    secure=True,
    verify=True  # Verify SSL certificate
)

# Or for native protocol
client = clickhouse_connect.get_client(
    host='ch.domain.com',
    port=9440,
    username='admin',
    password='your_password',
    secure=True
)
```

---

## Phụ lục A: Cài đặt ClickHouse

### Quick Install (Ubuntu/Debian)

```bash
# Cài đặt nhanh qua script
# Quick install via script
sudo bash -c "$(curl -fsSL https://clickhouse.com/install.sh)"

# Khởi động service
# Start service
sudo clickhouse start
```

### Package Install

```bash
# Thêm repository
# Add repository
sudo apt-get install -y apt-transport-https ca-certificates dirmngr
GNUPGHOME=$(mktemp -d)
sudo GNUPGHOME="$GNUPGHOME" gpg --no-default-keyring \
    --keyring /usr/share/keyrings/clickhouse-keyring.gpg \
    --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8919F6BD2B48D754

sudo rm -r "$GNUPGHOME"
sudo chmod +r /usr/share/keyrings/clickhouse-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] \
    https://packages.clickhouse.com/deb stable main" | \
    sudo tee /etc/apt/sources.list.d/clickhouse.list

# Cài đặt
# Install
sudo apt-get update
sudo apt-get install -y clickhouse-server clickhouse-client

# Khởi động
# Start
sudo systemctl enable clickhouse-server
sudo systemctl start clickhouse-server
```

---

## Phụ lục B: Tự tạo chứng chỉ SSL (Development)

**Chỉ dùng cho môi trường phát triển, KHÔNG dùng cho production!**

**For development only, NOT for production!**

```bash
# Sử dụng script có sẵn
# Use provided script
cd /path/to/clickhouse/quickstart_certs
sudo ./scripts/generate-certs.sh --domain ch.domain.com

# Hoặc tự tạo
# Or create manually
sudo mkdir -p /etc/clickhouse-server/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/clickhouse-server/certs/server.key \
    -out /etc/clickhouse-server/certs/server.crt \
    -subj "/CN=ch.domain.com"

sudo chown -R clickhouse:clickhouse /etc/clickhouse-server/certs
sudo chmod 600 /etc/clickhouse-server/certs/*
```

---

## Khắc phục sự cố | Troubleshooting

### Lỗi Code 76 (Status file exists)

```bash
# Xóa file lock
sudo rm -f /var/lib/clickhouse/status
sudo systemctl restart clickhouse-server
```

### Lỗi SSL/TLS

```bash
# Kiểm tra chứng chỉ
# Check certificate
openssl x509 -in /etc/letsencrypt/live/ch.domain.com/fullchain.pem -text -noout

# Kiểm tra kết nối SSL
# Test SSL connection
openssl s_client -connect ch.domain.com:9440 -servername ch.domain.com
```

### Không thể kết nối qua Cloudflare

1. Kiểm tra DNS có trỏ đúng IP không
2. Kiểm tra chế độ Proxy (Orange/Gray cloud)
3. Kiểm tra SSL/TLS mode (phải là Full Strict)
4. Kiểm tra firewall rules trong Cloudflare

**Check:**
1. DNS points to correct IP
2. Proxy mode (Orange/Gray cloud)
3. SSL/TLS mode (must be Full Strict)
4. Cloudflare firewall rules

---

## Tài liệu tham khảo | References

- [ClickHouse Official Documentation](https://clickhouse.com/docs)
- [ClickHouse SSL/TLS Configuration](https://clickhouse.com/docs/en/operations/server-configuration-parameters/settings#openssl)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Cloudflare SSL/TLS Docs](https://developers.cloudflare.com/ssl/)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)

---

*Last updated: March 2025*
