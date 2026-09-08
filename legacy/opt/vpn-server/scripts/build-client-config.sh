#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check arguments
if [[ -z "$1" ]]; then
    log_error "Usage: $0 <client-name>"
    exit 1
fi

CLIENT_NAME="$1"
EASYRSA_DIR="/opt/easy-rsa"
OPENVPN_DIR="/etc/openvpn/server"
OUTPUT_DIR="/home/yc-user/clients"
VPN_SERVER_IP="${VPN_SERVER_IP:-<VPN_SERVER_IP>}"

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check signed certificate exists
if [[ ! -f "/tmp/${CLIENT_NAME}.crt" ]]; then
    log_error "Signed certificate not found: /tmp/${CLIENT_NAME}.crt"
    log_error "Please copy signed certificate from CA server first"
    exit 1
fi

# Check client key exists
if [[ ! -f "${EASYRSA_DIR}/pki/private/${CLIENT_NAME}.key" ]]; then
    log_error "Client key not found: ${EASYRSA_DIR}/pki/private/${CLIENT_NAME}.key"
    log_error "Please run generate-client.sh first"
    exit 1
fi

log_info "Building client config for: $CLIENT_NAME"

mkdir -p "$OUTPUT_DIR"

# Copy signed cert to easy-rsa
cp "/tmp/${CLIENT_NAME}.crt" "$EASYRSA_DIR/pki/issued/"

# Build .ovpn file
cat > "${OUTPUT_DIR}/${CLIENT_NAME}.ovpn" << OVPN
client
dev tun
proto udp
remote ${VPN_SERVER_IP} 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
key-direction 1
verb 3

<ca>
$(cat ${OPENVPN_DIR}/ca.crt)
</ca>

<cert>
$(cat ${EASYRSA_DIR}/pki/issued/${CLIENT_NAME}.crt)
</cert>

<key>
$(cat ${EASYRSA_DIR}/pki/private/${CLIENT_NAME}.key)
</key>

<tls-auth>
$(cat ${OPENVPN_DIR}/ta.key)
</tls-auth>
OVPN

chown yc-user:yc-user "${OUTPUT_DIR}/${CLIENT_NAME}.ovpn"
chmod 600 "${OUTPUT_DIR}/${CLIENT_NAME}.ovpn"

log_info "============================================"
log_info "Client config created!"
log_info "File: ${OUTPUT_DIR}/${CLIENT_NAME}.ovpn"
log_info "============================================"
echo ""
echo "Download to your machine:"
echo "  scp yc-user@${VPN_SERVER_IP}:${OUTPUT_DIR}/${CLIENT_NAME}.ovpn ."