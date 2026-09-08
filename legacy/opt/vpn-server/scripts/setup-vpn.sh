#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Configuration
VPN_SERVER_NAME="${VPN_SERVER_NAME:-vpn-server}"
VPN_NETWORK="${VPN_NETWORK:-10.8.0.0}"
VPN_NETMASK="${VPN_NETMASK:-255.255.255.0}"
VPN_PORT="${VPN_PORT:-1194}"
VPN_PROTO="${VPN_PROTO:-udp}"

log_info "============================================"
log_info "VPN Server Setup"
log_info "============================================"

# Install packages
log_info "Installing OpenVPN and Easy-RSA..."
apt-get update
apt-get install -y openvpn easy-rsa

# Setup Easy-RSA for CSR generation
log_info "Setting up Easy-RSA..."
mkdir -p /opt/easy-rsa
cp -r /usr/share/easy-rsa/* /opt/easy-rsa/
cd /opt/easy-rsa

# Configure vars with proper CN
cat > vars << EOF
set_var EASYRSA_BATCH          "yes"
set_var EASYRSA_REQ_CN         "${VPN_SERVER_NAME}"
set_var EASYRSA_REQ_COUNTRY    "RU"
set_var EASYRSA_REQ_PROVINCE   "Moscow"
set_var EASYRSA_REQ_CITY       "Moscow"
set_var EASYRSA_REQ_ORG        "DevOps Diploma"
set_var EASYRSA_REQ_EMAIL      "admin@local"
set_var EASYRSA_REQ_OU         "VPN"
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_ALGO           rsa
set_var EASYRSA_CERT_EXPIRE    825
EOF

# Init PKI (for CSR generation only, not CA)
./easyrsa init-pki

# Create directory structure for signed certificates
mkdir -p /opt/easy-rsa/pki/issued

# Generate server key and CSR
log_info "Generating server key and CSR..."
./easyrsa --batch gen-req "$VPN_SERVER_NAME" nopass

# Copy server key to OpenVPN
mkdir -p /etc/openvpn/server
cp "/opt/easy-rsa/pki/private/${VPN_SERVER_NAME}.key" /etc/openvpn/server/
chmod 600 "/etc/openvpn/server/${VPN_SERVER_NAME}.key"

# Generate DH parameters
log_info "Generating DH parameters (this may take a while)..."
openssl dhparam -out /etc/openvpn/server/dh.pem 2048
chmod 600 /etc/openvpn/server/dh.pem

# Generate TLS auth key
log_info "Generating TLS auth key..."
openvpn --genkey secret /etc/openvpn/server/ta.key
chmod 600 /etc/openvpn/server/ta.key

# Create server config
log_info "Creating server configuration..."
cat > /etc/openvpn/server/server.conf << EOF
port ${VPN_PORT}
proto ${VPN_PROTO}
dev tun
ca ca.crt
cert ${VPN_SERVER_NAME}.crt
key ${VPN_SERVER_NAME}.key
dh dh.pem
tls-auth ta.key 0
server ${VPN_NETWORK} ${VPN_NETMASK}
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-GCM
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
verb 3
EOF

# Enable IP forwarding
log_info "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf

# Copy CSR to /tmp for easy access
cp "/opt/easy-rsa/pki/reqs/${VPN_SERVER_NAME}.req" /tmp/
chmod 644 "/tmp/${VPN_SERVER_NAME}.req"

log_info "============================================"
log_info "VPN Server base setup complete!"
log_info "============================================"
echo ""
log_warn "NEXT STEPS:"
echo "1. CSR is at: /tmp/${VPN_SERVER_NAME}.req"
echo "2. Send CSR to CA server for signing"
echo "3. Copy signed certificate to /etc/openvpn/server/${VPN_SERVER_NAME}.crt"
echo "4. Copy CA certificate to /etc/openvpn/server/ca.crt"
echo "5. Run: systemctl enable --now openvpn-server@server"