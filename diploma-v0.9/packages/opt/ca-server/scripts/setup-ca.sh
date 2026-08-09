#!/bin/bash
set -e

# =====================================================
# Скрипт установки Easy-RSA и создания CA
# =====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка root
if [[ $EUID -ne 0 ]]; then
    log_error "Скрипт должен запускаться от root (sudo)"
    exit 1
fi

# Переменные
EASYRSA_DIR="/opt/easy-rsa"
PKI_DIR="/opt/easy-rsa/pki"
CA_NAME="${CA_NAME:-MyCompany-CA}"

# 1. Установка Easy-RSA
log_info "Установка Easy-RSA..."
apt-get update
apt-get install -y easy-rsa

# 2. Создание рабочей директории
log_info "Создание рабочей директории CA..."
if [[ -d "$EASYRSA_DIR" ]]; then
    log_warn "Директория $EASYRSA_DIR уже существует"
    read -p "Удалить и создать заново? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Прервано пользователем"
        exit 0
    fi
    rm -rf "$EASYRSA_DIR"
fi

make-cadir "$EASYRSA_DIR"
cd "$EASYRSA_DIR"

# 3. Настройка vars
log_info "Настройка переменных Easy-RSA..."
cat > "$EASYRSA_DIR/vars" << EOF
# Easy-RSA configuration
set_var EASYRSA_REQ_COUNTRY    "RU"
set_var EASYRSA_REQ_PROVINCE   "Moscow"
set_var EASYRSA_REQ_CITY       "Moscow"
set_var EASYRSA_REQ_ORG        "MyCompany"
set_var EASYRSA_REQ_EMAIL      "admin@mycompany.local"
set_var EASYRSA_REQ_OU         "IT Department"
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_ALGO           rsa
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    365
set_var EASYRSA_BATCH          "yes"
EOF

# 4. Инициализация PKI
log_info "Инициализация PKI..."
./easyrsa init-pki

# 5. Создание корневого сертификата CA
log_info "Создание корневого сертификата CA..."
./easyrsa --batch --req-cn="$CA_NAME" build-ca nopass

# 6. Установка прав доступа
log_info "Установка прав доступа..."
chmod 700 "$PKI_DIR/private"
chmod 600 "$PKI_DIR/private/"*

# 7. Вывод информации
log_info "=========================================="
log_info "CA успешно создан!"
log_info "=========================================="
log_info "Директория PKI: $PKI_DIR"
log_info "Корневой сертификат: $PKI_DIR/ca.crt"
log_info "Приватный ключ CA: $PKI_DIR/private/ca.key"
log_info ""
log_info "Информация о сертификате:"
openssl x509 -in "$PKI_DIR/ca.crt" -noout -subject -dates