# Backup System

## 1. Overview

### 1.1 What we backup


| Component | Criticality | Data | Frequency |
| :--- | :--- | :--- | :--- |
| CA (ca-vm) | CRITICAL | CA private key, issued certificates | On change + Daily |
| VPN (vpn-vm) | High | Configs, server certificate | On change |
| Monitoring (monitoring-vm) | Medium | Prometheus configs, metrics data | Daily |
| Scripts/DEB packages | High | All deployment artifacts | On change (Git) |


### 1.2 Architecture (3-2-1 Rule)

- **Copy 1**: GitHub (.deb packages, scripts, documentation)
- **Copy 2**: backup-vm (Gitea mirror, .deb repo, CA backups)
- **Copy 3**: Yandex.Cloud snapshots (VM images)

### 1.3 Components

| Component | Purpose | Location |
|-----------|-------------|--------------|
| GitHub | Main Code Repository | Offsite |
| Gitea | Local Git Mirror | backup-vm |
| reprepro | APT repository of .deb packages | backup-vm |
| GPG-encrypted backups | CA backups | backup-vm |
| YC Snapshots | VM disk images | Yandex.Cloud |

## 2. Failure Scenarios

### Scenario 1: CA-VM Failure — Recovery Commands

# Option A: Restore from a YC snapshot
yc compute instance create --name ca-vm-restored \
  --zone ru-central1-a \
  --create-boot-disk snapshot-name=<snapshot-name>

# Option B: Restore from a file backup
# 1. Create a new VM, install the deb package
`sudo dpkg -i ca-server-config.deb`
`sudo /opt/ca-server/scripts/setup-security.sh`

# 2. Restore PKI from backup (on backup-vm)
`scp backup-vm:/var/backups/ca/ca-backup-YYYYMMDD.tar.gz /tmp/`

# 3. Unpack PKI
`sudo tar xzf /tmp/ca-backup-YYYYMMDD.tar.gz -C /`

# 4. Check CA
`ls -la /opt/easy-rsa/pki/`
`sudo cat /opt/easy-rsa/pki/ca.crt | openssl x509 -noout -subject`

**Cause**: Hardware failure, OS error, accidental deletion

**Consequences**:
- Unable to issue new certificates
- Unable to revoke certificates
- Existing VPN connections continue to work


### Scenario 2: VPN-VM Failure

**Cause**: Hardware failure, DDoS, configuration error

**Consequences**:
- All VPN clients lose access
- No access to the internal network

**Recovery Steps**:
1. Create a new VM from a snapshot YC
2. Or: deploy from the deb package, obtain a new certificate from the CA
3. Update DNS/IP if changed
4. Recovery time: 15-30 minutes

### Scenario 3: CA private key compromise

**Cause**: Hack, leak, insider

**Consequences**:
- CRITICAL: attacker can issue valid certificates
- Entire infrastructure compromised

**Recovery actions**:
1. IMMEDIATELY: stop the CA server
2. Revoke ALL issued certificates
3. Recreate the CA from scratch (new root key)
4. Reissue certificates for all servers and clients
5. Distribute new client configs
6. Investigate the incident
7. Recovery time: 2-4 hours

### Scenario 4: Loss of access to GitHub

**Reason**: Account blocked, GitHub unavailable, repository deleted

**Consequences**:
- No access to scripts and deb packages
- Unable to deploy infrastructure from scratch

**Recovery steps**:
1. Use a mirror on backup-vm (Gitea)
2. Use a local deb repository (reprepro)
3. Recovery time: 5 minutes (switch to backup-vm)

### Scenario 5: Complete infrastructure destruction

**Reason**: Cloud account deletion, data center disaster, administrator error

**Consequences**:
- Complete loss of all services

**Recovery steps**:
1. Create a new cloud account/project
2. Deploy backup-vm first (from GitHub or a local copy)
3. Clone the repository from GitHub
4. Deploy CA From a DEB package + restore PKI from an encrypted backup
5. Deploy VPN from a DEB package + obtain a certificate
6. Deploy Monitoring from a DEB package
7. Reissue client certificates
8. Recovery time: 1-2 hours

## 3. Platform capabilities vs. self-hosted implementation

| Task | Yandex.Cloud | Self-hosted | Choice |
|--------|--------------|----------------|-------|
| VM snapshots | ✅ Built-in scheduled snapshots | Scripts + dd/rsync | YC (simpler, more reliable) |
| Artifact storage | Object Storage (S3) — paid | GitHub + Gitea | Self-hosted (free) |
| DEB repository | No | reprepro | Self-hosted |
| Database backup | Managed DB has built-in | pg_dump/mysqldump | No database in the project |
| Geo-distribution | Multiple availability zones | — | YC (backup-vm in zone b) |

## 4. Storing scripts and deb packages

### 4.1 Main repository: GitHub

- Repository: [your repository]
- Contents: scripts, deb packages, documentation, configs
- Versioning: Git tags for releases

### 4.2 Backup repository: backup-vm

- Gitea: GitHub mirror (auto-synchronization)
- reprepro: APT repository for deb packages
- Access: via VPN or directly (for disaster recovery)


## 5. Backup Procedures

### 5.1 CA (Critical Data)

- **What:** `/opt/easy-rsa/pki/` (private key, certificates, CRL)
- **Where:** backup-vm:/backups/ca/ (GPG-encrypted)
- **How:** backup-ca.sh script + cron
- **Frequency:** Every change + daily
- **Retain:** 30 days

### 5.2 VM Snapshots

- **What:** Disks of all VMs
- **Where:** Yandex.Cloud Snapshots
- **How:** Schedule in YC Console
- **Frequency:** Daily
- **Retention:** 7 days

### 5.3 Git repository

- **What:** All code and documentation
- **Where:** GitHub → Gitea (mirror)
- **How:** Gitea mirror sync
- **Frequency:** Every 6 hours

## 6. Recovery Testing

| Component | Criticality | Data | Frequency |
|-----------|------------|------|-----------|
| Restore CA from backup | Monthly | Deploy a test VM, restore PKI |
| Restore VM from snapshot | Monthly | Create VM from snapshot, check services |
| Cloning from Gitea | On change | git clone from backup-vm |
| Install from local deb repo | On change | apt install from backup-vm |

## 7. Backup System Monitoring

### Alerts:
- backup-vm unavailable (node_exporter)
- Gitea unavailable (probe)
- CA backup older than 24 hours
- backup-vm disk full > 80

### Prometheus Metrics:
- `backup_ca_success` — 1 if the last backup was successful
- `backup_ca_timestamp` — timestamp of the last backup
- `backup_ca_size_bytes` — size of the last backup
- `up{job="backup-vm"}` — availability of backup-vm

### Alert Rules:
- CABackupStale: Backup older than 25 hours
- CABackupFailed: backup_ca_success == 0
- BackupVMDown: backup-vm unavailable for > 2 minutes


