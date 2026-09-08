# VPN Server (OpenVPN)

OpenVPN сервер с интеграцией с удостоверяющим центром (CA).

## Архитектура
[Клиент] ──VPN──▶ [VPN-сервер] ◀──CSR/CRT──▶ [CA-сервер]
(10.8.0.0/24)

- VPN-сервер генерирует ключи и CSR
- CA-сервер подписывает сертификаты
- Клиенты получают .ovpn файлы для подключения

## Установка

### Вариант 1: DEB-пакет (рекомендуется)

```bash
sudo dpkg -i vpn-server_1.0.0_all.deb
sudo /opt/vpn-server/scripts/setup-vpn.sh
sudo /opt/vpn-server/scripts/setup-security.sh
```
### Вариант 2: Скрипты вручную

```bash
sudo ./setup-vpn.sh
sudo ./setup-security.sh
```

## Настройка переменных окружения


| Переменная | По умолчанию | Описание |
| :--- | :--- | :--- |
| **VPN_SERVER_NAME** | vpn-server | Имя сервера (CN в сертификате) |
| **VPN_NETWORK** | 10.8.0.0 | VPN подсеть |
| **VPN_NETMASK** | 255.255.255.0 | Маска подсети |
| **VPN_PORT** | 1194 | Порт OpenVPN |
| **VPN_SERVER_IP** | - | Внешний IP сервера |

## Процедура подписания серверного сертификата

### 1. После запуска setup-vpn.sh
CSR находится в `/tmp/vpn-server.req`

### 2. Копирование на локальную машину
`scp yc-user@<VPN_IP>:/tmp/vpn-server.req .`

### 3. Отправка на CA-сервер
`scp vpn-server.req yc-user@<CA_IP>:/tmp/`

### 4. Подписание на CA-сервере
```bash
cd /opt/easy-rsa
sudo ./easyrsa import-req /tmp/vpn-server.req vpn-server
sudo ./easyrsa sign-req server vpn-server
sudo cp /opt/easy-rsa/pki/issued/vpn-server.crt /tmp/
sudo chmod 644 /tmp/vpn-server.crt
```
### 5. Возврат сертификатов
```bash
# На локалке
scp yc-user@<CA_IP>:/tmp/vpn-server.crt .
scp yc-user@<CA_IP>:/opt/easy-rsa/pki/ca.crt .

# На VPN-сервер
scp vpn-server.crt yc-user@<VPN_IP>:/tmp/
scp ca.crt yc-user@<VPN_IP>:/tmp/

# На VPN-сервере
sudo cp /tmp/vpn-server.crt /etc/openvpn/server/
sudo cp /tmp/ca.crt /etc/openvpn/server/
```

### 6. Запуск OpenVPN
```bash
sudo systemctl enable --now openvpn-server@server
sudo systemctl status openvpn-server@server
```

## Процедура выдачи клиентских сертификатов

### 1. Генерация CSR на VPN-сервере
`sudo /opt/vpn-server/scripts/generate-client.sh <client-name>`

### 2. Подписание на CA-сервере
```bash
# На локалке - забрать CSR
scp yc-user@<VPN_IP>:/tmp/<client-name>.req .
scp <client-name>.req yc-user@<CA_IP>:/tmp/

# На CA-сервере
cd /opt/easy-rsa
sudo ./easyrsa import-req /tmp/<client-name>.req <client-name>
sudo ./easyrsa sign-req client <client-name>
sudo cp /opt/easy-rsa/pki/issued/<client-name>.crt /tmp/
sudo chmod 644 /tmp/<client-name>.crt
```

### 3. Сборка .ovpn файла
```bash
# На локалке - вернуть сертификат
scp yc-user@<CA_IP>:/tmp/<client-name>.crt .
scp <client-name>.crt yc-user@<VPN_IP>:/tmp/

# На VPN-сервере
sudo /opt/vpn-server/scripts/build-client-config.sh <client-name>
```
### 4. Получение конфига
`scp yc-user@<VPN_IP>:/home/yc-user/clients/<client-name>.ovpn .`

## Проверка работоспособности
```bash
# Статус сервиса
sudo systemctl status openvpn-server@server

# Интерфейс туннеля
ip addr show tun0

# Подключенные клиенты
sudo cat /var/log/openvpn/status.log

# Firewall
sudo ufw status verbose
```

## Структура файлов

/etc/openvpn/server/
├── server.conf      # Конфигурация сервера
├── ca.crt           # Сертификат CA
├── vpn-server.crt   # Сертификат сервера
├── vpn-server.key   # Ключ сервера
├── dh.pem           # DH параметры
└── ta.key           # TLS-auth ключ

/opt/vpn-server/scripts/
├── setup-vpn.sh           # Установка OpenVPN
├── setup-security.sh      # Настройка UFW и NAT
├── generate-client.sh     # Генерация клиентского CSR
└── build-client-config.sh # Сборка .ovpn файла

/opt/easy-rsa/
└── pki/
    ├── private/     # Приватные ключи
    ├── reqs/        # CSR запросы
    └── issued/      # Подписанные сертификаты