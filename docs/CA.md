# Certificate Authority Server

## Overview
Internal Certificate Authority (CA) for issuing certificates to infrastructure services.
Built with Easy-RSA on Ubuntu 22.04.

## Server Info

| Параметр | Значение |
|----------|----------|
| VM | ca-vm |
| Internal IP | 10.10.0.6 |
| OS | Ubuntu 22.04 |
| PKI Location | `/opt/easy-rsa/pki/` |

## Components
- `setup-security.sh` - Firewall (UFW) and fail2ban configuration
- `setup-ca.sh` - Easy-RSA PKI initialization and root CA creation
- `ca-server-config.deb` - Deployment package with all configurations
- `node-exporter_1.7.0_amd64.deb` - Metrics exporter for Prometheus

## Installation

```bash
# Install packages
sudo dpkg -i ca-server-config.deb
sudo dpkg -i node-exporter_1.7.0_amd64.deb
sudo apt-get install -f -y

# Run setup scripts
sudo /opt/ca-server/scripts/setup-security.sh
sudo /opt/ca-server/scripts/setup-ca.sh
```

## Certificate Details


| Parameter | Meaning |
|----------|----------|
| CN | MyCompany-CA |
| Validity | 10 years |
| Algorithm | RSA 2048 |


## PKI Structure

/opt/easy-rsa/pki/
├── ca.crt              # Root CA certificate (public)
├── private/
│   └── ca.key          # Root CA private key (PROTECT!)
├── issued/             # Signed certificates
├── reqs/               # Certificate signing requests
└── crl.pem             # Certificate revocation list

## Operations

**Signing Server Certificate**
```bash
cd /opt/easy-rsa
sudo ./easyrsa import-req /path/to/request.req server-name
sudo ./easyrsa sign-req server server-name
```

**Signing Client Certificate**
```bash
cd /opt/easy-rsa
sudo ./easyrsa import-req /path/to/client.req client-name
sudo ./easyrsa sign-req client client-name
```

**Revoking Certificate**
```bash
cd /opt/easy-rsa
sudo ./easyrsa revoke client-name
sudo ./easyrsa gen-crl
# Copy CRL to VPN server
scp pki/crl.pem vpn-vm:/etc/openvpn/server/
```

## Firewall Rules


| Port | Protocol | Status | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Open | SSH access |
| 9100 | TCP | Open | node_exporter metrics |
| * | * | Closed | All other traffic |


## Security
✅ No external IP (air-gapped CA recommended)
✅ ca.key permissions: 600, owner: root
✅ UFW firewall enabled

### Critical Files


| File | Protection Level | Description |
|------|------------------|-------------|
| ca.key | 🔴 CRITICAL | CA private key - compromise = full PKI rebuild |
| ca.crt | 🟢 Public | Can be distributed |
| *.key | 🟠 High | Server/client private keys |


## Backup

CA backup is automated via cron job.
See BACKUP.md for details.

## Monitoring

- `node_exporter` running on port 9100
- Metrics scraped by Prometheus (monitoring-vm)
Alert: `CAVMDown` - triggers if ca-vm unreachable for 5+ minutes

## Troubleshooting

**"CA certificate not found"**
```bash
# Verify CA exists
ls -la /opt/easy-rsa/pki/ca.crt

# If missing - reinitialize (WARNING: destroys existing PKI!)
cd /opt/easy-rsa
./easyrsa init-pki
./easyrsa build-ca
```

**"CRL has expired"**
```bash
cd /opt/easy-rsa
./easyrsa gen-crl
scp pki/crl.pem vpn-vm:/etc/openvpn/server/
sudo systemctl restart openvpn-server@server
```