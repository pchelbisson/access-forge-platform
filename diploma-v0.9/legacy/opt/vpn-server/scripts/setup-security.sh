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

# Detect main network interface
MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)
if [[ -z "$MAIN_IF" ]]; then
    log_error "Cannot detect main network interface"
    exit 1
fi
log_info "Detected main interface: $MAIN_IF"

VPN_PORT="${VPN_PORT:-1194}"
VPN_NETWORK="${VPN_NETWORK:-10.8.0.0/24}"
SSH_PORT="${SSH_PORT:-22}"

log_info "============================================"
log_info "VPN Security Setup"
log_info "============================================"

# Configure UFW
log_info "Configuring UFW firewall..."

# Reset UFW to clean state
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow ${SSH_PORT}/tcp comment 'SSH'

# Allow OpenVPN
ufw allow ${VPN_PORT}/udp comment 'OpenVPN'

# Configure NAT BEFORE enabling UFW
log_info "Configuring NAT for VPN..."

# Backup existing before.rules
cp /etc/ufw/before.rules /etc/ufw/before.rules.backup

# Add NAT rules at the beginning of before.rules
cat > /tmp/nat_rules << EOF
# NAT table rules for OpenVPN
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s ${VPN_NETWORK} -o ${MAIN_IF} -j MASQUERADE
COMMIT

EOF

# Prepend NAT rules to before.rules
cat /tmp/nat_rules /etc/ufw/before.rules.backup > /etc/ufw/before.rules
rm /tmp/nat_rules

# Enable forwarding in UFW
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw

# Now enable UFW
log_info "Enabling UFW..."
ufw --force enable

log_info "============================================"
log_info "Security setup complete!"
log_info "============================================"
ufw status verbose
