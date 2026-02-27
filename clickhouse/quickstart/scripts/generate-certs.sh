#!/bin/bash
#
# Generate TLS Certificates for ClickHouse
# Following official ClickHouse documentation
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DOMAIN=""
IP=""
CERT_DIR="/etc/clickhouse-server/certs"
CA_NAME="marsnet_ca"
DAYS=365

# Function to print colored output
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Help message
show_help() {
    cat << EOF
Generate TLS certificates for ClickHouse following official documentation

Usage: $0 [OPTIONS]

Options:
    -d, --domain DOMAIN     Domain name (e.g., your-domain.com)
    -i, --ip IP_ADDRESS     Server IP address (e.g., 192.168.1.100)
    -c, --ca-only           Generate only CA certificate
    -h, --help             Show this help message

Examples:
    # Generate CA only
    $0 --ca-only

    # Generate CA and server certificates
    $0 --domain example.com --ip 192.168.1.100

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -i|--ip)
            IP="$2"
            shift 2
            ;;
        -c|--ca-only)
            CA_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root or with sudo"
   exit 1
fi

# Create certs directory
print_info "Creating certificate directory..."
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Generate CA Certificate
print_info "Generating CA certificate..."

# Generate CA key
openssl genrsa -out ${CA_NAME}.key 2048
print_success "CA key generated: ${CA_NAME}.key"

# Generate self-signed CA certificate (1095 days = 3 years)
openssl req -x509 -subj "/CN=marsnet.local CA" -nodes \
    -key ${CA_NAME}.key -days 1095 -out ${CA_NAME}.crt
print_success "CA certificate generated: ${CA_NAME}.crt"

# Verify CA certificate
print_info "Verifying CA certificate..."
openssl x509 -in ${CA_NAME}.crt -text -noout | head -20

print_info ""
print_info "CA Certificate Details:"
openssl x509 -in ${CA_NAME}.crt -noout -subject -dates

if [[ "$CA_ONLY" == true ]]; then
    print_success "CA certificate generated successfully!"
    print_info ""
    print_info "IMPORTANT: Backup these files to a secure location:"
    print_info "  - ${CERT_DIR}/${CA_NAME}.key"
    print_info "  - ${CERT_DIR}/${CA_NAME}.crt"
    print_info ""
    print_info "Then delete ${CA_NAME}.key from this server for security."
    exit 0
fi

# Validate required parameters for server certificate
if [[ -z "$DOMAIN" ]] || [[ -z "$IP" ]]; then
    print_error "Domain and IP are required for server certificate generation"
    print_info "Usage: $0 --domain example.com --ip 192.168.1.100"
    exit 1
fi

# Generate Server Certificate
print_info ""
print_info "Generating server certificate..."

# Create certificate request and key
openssl req -newkey rsa:2048 -nodes \
    -subj "/CN=server" \
    -addext "subjectAltName = DNS:${DOMAIN},IP:${IP}" \
    -keyout server.key -out server.csr
print_success "Server key and CSR generated"

# Sign with CA
openssl x509 -req -in server.csr -out server.crt \
    -CA ${CA_NAME}.crt -CAkey ${CA_NAME}.key -days ${DAYS} -copy_extensions copy
print_success "Server certificate signed by CA"

# Verify certificate
print_info ""
print_info "Verifying server certificate..."
openssl verify -CAfile ${CA_NAME}.crt server.crt

print_info ""
print_info "Server Certificate Details:"
openssl x509 -in server.crt -noout -subject -dates

# Set permissions
print_info ""
print_info "Setting certificate permissions..."
chown clickhouse:clickhouse -R "$CERT_DIR"
chmod 600 "$CERT_DIR"/*
chmod 755 "$CERT_DIR"

# List files
print_info ""
print_info "Certificate files created:"
ls -la "$CERT_DIR/"

print_success ""
print_success "Certificate generation complete!"
print_info ""
print_info "IMPORTANT SECURITY STEPS:"
print_info "1. Backup these files to a secure location:"
print_info "   - ${CERT_DIR}/${CA_NAME}.key"
print_info "   - ${CERT_DIR}/${CA_NAME}.crt"
print_info ""
print_info "2. Delete the CA private key from this server:"
print_info "   rm ${CERT_DIR}/${CA_NAME}.key"
print_info ""
print_info "3. Configure ClickHouse to use the certificates in:"
print_info "   /etc/clickhouse-server/config.d/ssl.xml"
