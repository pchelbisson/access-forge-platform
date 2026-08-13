#!/bin/bash
set -euo pipefail

# Конфигурация
BACKUP_DIR="/var/backups/ca"
REMOTE_USER="yc-user"
REMOTE_HOST="10.10.0.6"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="ca-backup-${DATE}.tar.gz"
RETENTION_DAYS=30
METRICS_FILE="/var/lib/node_exporter/textfile/backup_ca.prom"

# Создаём директории
mkdir -p /var/lib/node_exporter/textfile
mkdir -p ${BACKUP_DIR}

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Начало бэкапа
log "Starting CA backup..."
START_TIME=$(date +%s)

# Забираем данные с CA-сервера
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo tar czf - /opt/easy-rsa" > "${BACKUP_DIR}/${BACKUP_NAME}" 2>/dev/null

# Проверяем размер
BACKUP_SIZE=$(stat -c%s "${BACKUP_DIR}/${BACKUP_NAME}")

if [ "$BACKUP_SIZE" -lt 1000 ]; then
    log "ERROR: Backup too small, something went wrong"
    echo "backup_ca_success 0" > "$METRICS_FILE"
    echo "backup_ca_timestamp $(date +%s)" >> "$METRICS_FILE"
    exit 1
fi

# Удаляем старые бэкапы
find ${BACKUP_DIR} -name "ca-backup-*.tar.gz" -mtime +${RETENTION_DAYS} -delete

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log "Backup completed: ${BACKUP_NAME} (${BACKUP_SIZE} bytes, ${DURATION}s)"

# Записываем метрики для Prometheus
cat > "$METRICS_FILE" <<METRICS
# HELP backup_ca_success Whether the last CA backup was successful
# TYPE backup_ca_success gauge
backup_ca_success 1
# HELP backup_ca_timestamp Timestamp of last successful backup
# TYPE backup_ca_timestamp gauge
backup_ca_timestamp $(date +%s)
# HELP backup_ca_size_bytes Size of last backup in bytes
# TYPE backup_ca_size_bytes gauge
backup_ca_size_bytes ${BACKUP_SIZE}
# HELP backup_ca_duration_seconds Duration of last backup
# TYPE backup_ca_duration_seconds gauge
backup_ca_duration_seconds ${DURATION}
METRICS

log "Metrics written to ${METRICS_FILE}"
