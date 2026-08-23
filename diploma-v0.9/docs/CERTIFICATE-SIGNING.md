## Signing a client certificate (manual step)

After generating a client CSR via Ansible (`-e client_name=<name>`), sign it manually on the CA server:

1. Copy CSR from VPN server to your local machine:
   `scp devops@<VPN_IP>:/opt/vpn-easy-rsa/pki/reqs/<name>.req .`
2. Copy CSR to CA server:
   `scp <name>.req devops@<CA_IP>:/tmp/`
3. On the CA server, import and sign:
   `cd /opt/easy-rsa && sudo ./easyrsa import-req /tmp/<name>.req <name> && sudo ./easyrsa sign-req client <name>`
4. Copy the signed cert back through your local machine to the VPN server:
   `scp devops@<CA_IP>:/opt/easy-rsa/pki/issued/<name>.crt .`
   `scp <name>.crt devops@<VPN_IP>:/opt/vpn-easy-rsa/pki/issued/`
5. Re-run the playbook to build the `.ovpn` bundle:
   `ansible-playbook -i inventory.ini site.yml -e client_name=<name>`