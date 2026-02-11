# Certificate Authority Server

## Overview
Internal Certificate Authority (CA) for issuing certificates to infrastructure services.
Built with Easy-RSA on Ubuntu 22.04.

## Components
- `setup-security.sh` - Firewall (UFW) and fail2ban configuration
- `setup-ca.sh` - Easy-RSA PKI initialization and root CA creation
- `ca-server-config.deb` - Deployment package with all configurations

## Installation

```bash
# Install package
sudo dpkg -i ca-server-config.deb
sudo apt-get install -f -y

# Run setup scripts
sudo /opt/ca-server/scripts/setup-security.sh
sudo /opt/ca-server/scripts/setup-ca.sh
```
## Certificate Details

- CN: MyCompany-CA
- Validity: 10 years
- Algorithm: RSA 2048

## PKI Location

- `/opt/easy-rsa/pki/` - PKI directory
- `/opt/easy-rsa/pki/ca.crt` - Root CA certificate
- `/opt/easy-rsa/pki/private/ca.key` - Root CA private key (protected)

## Signing Client Certificates

```bash
cd /opt/easy-rsa
sudo ./easyrsa import-req /path/to/request.req entity-name
sudo ./easyrsa sign-req server entity-name
```

## Firewall

- Port 22/tcp (SSH) - open
- All other ports - closed

## Security

- fail2ban enabled for SSH protection
- No external network access required (air-gapped CA)