#!/bin/bash
set -e

# =====================================================
# Скрипт базовой настройки безопасности для CA-сервера
# =====================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка root
if [[ $EUID -ne 0 ]]; then
    log_error "Скрипт должен запускаться от root (sudo)"
    exit 1
fi

# 1. Обновление системы
log_info "Обновление системы..."
apt-get update && apt-get upgrade -y

# 2. Установка базовых пакетов
log_info "Установка базовых пакетов..."
apt-get install -y ufw fail2ban

# 3. Настройка UFW
log_info "Настройка firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw --force enable

# 4. Базовый hardening SSH (без локаута!)
log_info "Настройка SSH..."
SSH_CONFIG="/etc/ssh/sshd_config"

# Бэкап оригинала
cp "$SSH_CONFIG" "${SSH_CONFIG}.backup.$(date +%Y%m%d)" 2>/dev/null || true

# Применяем безопасные настройки
cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
# SSH Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# Перезапуск SSH
systemctl restart sshd

# 5. Настройка fail2ban для SSH
log_info "Настройка fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

systemctl enable fail2ban
systemctl restart fail2ban

log_info "Базовая настройка безопасности завершена!"
log_info "Открытые порты: 22 (SSH)"
ufw status verbose