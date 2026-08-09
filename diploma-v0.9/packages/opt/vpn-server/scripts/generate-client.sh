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

# Check arguments
if [[ -z "$1" ]]; then
    log_error "Usage: $0 <client-name>"
    echo "Example: $0 user1"
    exit 1
fi

CLIENT_NAME="$1"
EASYRSA_DIR="/opt/easy-rsa"
VPN_SERVER_IP="${VPN_SERVER_IP:-<VPN_SERVER_IP>}"

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

log_info "Generating client CSR for: $CLIENT_NAME"

cd "$EASYRSA_DIR"

# Check if client already exists
if [[ -f "pki/private/${CLIENT_NAME}.key" ]]; then
    log_warn "Client key already exists: ${CLIENT_NAME}"
    log_warn "CSR location: /tmp/${CLIENT_NAME}.req"
    exit 0
fi

# Set proper CN for this client
export EASYRSA_REQ_CN="$CLIENT_NAME"

# Generate client key and CSR
log_info "Generating client key and CSR..."
./easyrsa --batch gen-req "$CLIENT_NAME" nopass

# Copy CSR to /tmp for easy access
cp "$EASYRSA_DIR/pki/reqs/${CLIENT_NAME}.req" /tmp/
chmod 644 "/tmp/${CLIENT_NAME}.req"

log_info "============================================"
log_info "Client CSR generated!"
log_info "============================================"
echo ""
log_warn "NEXT STEPS (manual certificate signing):"
echo ""
echo "1. Copy CSR to your local machine:"
echo "   scp yc-user@${VPN_SERVER_IP}:/tmp/${CLIENT_NAME}.req ."
echo ""
echo "2. Copy CSR to CA server:"
echo "   scp ${CLIENT_NAME}.req yc-user@<CA_IP>:/tmp/"
echo ""
echo "3. On CA server, sign the certificate:"
echo "   cd /opt/easy-rsa"
echo "   sudo ./easyrsa import-req /tmp/${CLIENT_NAME}.req ${CLIENT_NAME}"
echo "   sudo ./easyrsa sign-req client ${CLIENT_NAME}"
echo ""
echo "4. Copy signed cert back through local machine:"
echo "   scp yc-user@<CA_IP>:/opt/easy-rsa/pki/issued/${CLIENT_NAME}.crt ."
echo "   scp ${CLIENT_NAME}.crt yc-user@${VPN_SERVER_IP}:/tmp/"
echo ""
echo "5. Then run on VPN server:"
echo "   sudo /opt/vpn-server/scripts/build-client-config.sh ${CLIENT_NAME}"
echo ""
log_info "CSR available at: /tmp/${CLIENT_NAME}.req"