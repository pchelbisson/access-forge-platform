# VPN Server (OpenVPN)

OpenVPN server with integration with a certificate authority (CA).

## Architecture
[Client] ──VPN──▶ [VPN Server] ◀──CSR/CRT──▶ [CA Server]
(10.8.0.0/24)

- The VPN server generates keys and CSRs
- The CA server signs certificates
- Clients receive .ovpn files for connection

## Components
- `vpn-server_1.0.0_all.deb` - VPN server deployment package

## Installation

```bash
sudo dpkg -i vpn-server_1.0.0_all.deb
sudo dpkg -i node-exporter_1.7.0_amd64.deb
sudo dpkg -i openvpn-exporter_0.3.0_amd64.deb
sudo apt-get install -f -y
# Run setup scripts
sudo /opt/vpn-server/scripts/setup-vpn.sh
sudo /opt/vpn-server/scripts/setup-security.sh

# Allow metrics from monitoring server only
sudo ufw allow from 10.10.0.11 to any port 9100 proto tcp comment "Node Exporter from Prometheus"
sudo ufw allow from 10.10.0.11 to any port 9176 proto tcp comment "OpenVPN Exporter from Prometheus"
```

### Option 2: Manual scripts
```bash
sudo ./setup-vpn.sh
sudo ./setup-security.sh
# Then install exporters manually
sudo dpkg -i node-exporter_1.7.0_amd64.deb
sudo dpkg -i openvpn-exporter_0.3.0_amd64.deb
```

## Setting environment variables


| Variable | Default | Description |
| :--- | :--- | :--- |
| **VPN_SERVER_NAME** | vpn-server | Server name (CN in certificate) |
| **VPN_NETWORK** | 10.8.0.0 | VPN subnet |
| **VPN_NETMASK** | 255.255.255.0 | Subnet mask |
| **VPN_PORT** | 1194 | OpenVPN port |
| **VPN_SERVER_IP** | - | Server external IP |

## Server Certificate Signing Procedure

### 1. After running setup-vpn.sh, the CSR is located in `/tmp/vpn-server.req`

### 2. Copy to the local machine
`scp yc-user@<VPN_IP>:/tmp/vpn-server.req .`

### 3. Send to the CA server
`scp vpn-server.req yc-user@<CA_IP>:/tmp/`

### 4. Signing on the CA server
```bash
cd /opt/easy-rsa
sudo ./easyrsa import-req /tmp/vpn-server.req vpn-server
sudo ./easyrsa sign-req server vpn-server
sudo cp /opt/easy-rsa/pki/issued/vpn-server.crt /tmp/
sudo chmod 644 /tmp/vpn-server.crt
```
### 5. Returning Certificates
```bash
# On the local network
scp yc-user@<CA_IP>:/tmp/vpn-server.crt .
scp yc-user@<CA_IP>:/opt/easy-rsa/pki/ca.crt .

# On the VPN server
scp vpn-server.crt yc-user@<VPN_IP>:/tmp/
scp ca.crt yc-user@<VPN_IP>:/tmp/

# On the VPN server
sudo cp /tmp/vpn-server.crt /etc/openvpn/server/
sudo cp /tmp/ca.crt /etc/openvpn/server/
```

### 6. Starting OpenVPN
```bash
sudo systemctl enable --now openvpn-server@server
sudo systemctl status openvpn-server@server
```

## Client certificate issuance procedure

### 1. Generating CSR on the VPN server
`sudo /opt/vpn-server/scripts/generate-client.sh <client-name>`

### 2. Signing on the CA server
```bash
# On the local network, retrieve the CSR
scp yc-user@<VPN_IP>:/tmp/<client-name>.req .
scp <client-name>.req yc-user@<CA_IP>:/tmp/

# On the CA server
cd /opt/easy-rsa
sudo ./easyrsa import-req /tmp/<client-name>.req <client-name>
sudo ./easyrsa sign-req client <client-name>
sudo cp /opt/easy-rsa/pki/issued/<client-name>.crt /tmp/
sudo chmod 644 /tmp/<client-name>.crt
```

### 3. Building the .ovpn file
```bash
# On the local network, return the certificate
scp yc-user@<CA_IP>:/tmp/<client-name>.crt .
scp <client-name>.crt yc-user@<VPN_IP>:/tmp/

# On the VPN server
sudo /opt/vpn-server/scripts/build-client-config.sh <client-name>
```
### 4. Getting the configuration
`scp yc-user@<VPN_IP>:/home/yc-user/clients/<client-name>.ovpn .`

## Health check
```bash
# Service status
sudo systemctl status openvpn-server@server

# Tunnel interface
ip addr show tun0

# Connected clients
sudo cat /var/log/openvpn/status.log

# Firewall
sudo ufw status verbose
```

## File Structure

/etc/openvpn/server/
├── server.conf             # Server Configuration
├── ca.crt                  # CA Certificate
├── vpn-server.crt          # Server Certificate
├── vpn-server.key          # Server Key
├── dh.pem                  # DH Parameters
└── ta.key                  # TLS-auth Key

/opt/vpn-server/scripts/
├── setup-vpn.sh            # Install OpenVPN
├── setup-security.sh       # Configure UFW and NAT
├── generate-client.sh      # Generate client CSR
└── build-client-config.sh  # Build .ovpn file

/opt/easy-rsa/
└── pki/
├── private/                # Private keys
├── reqs/                   # CSR requests
└── issued/                 # Signed certificates