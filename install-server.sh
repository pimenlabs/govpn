#!/usr/bin/env bash
# ==============================================================================
# Script Otomatis Instalasi OpenVPN Management API & Dashboard
# Target OS: Ubuntu 20.04 / 22.04 / 24.04 atau Debian 11 / 12
# ==============================================================================

set -e

# Warna Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Konfigurasi Default
APP_DIR="/opt/openvpn-api"
APP_PORT="${PORT:-8000}"
DB_NAME="${DB_NAME:-appdb}"
DB_USER="${DB_USER:-appuser}"
DB_PASS="${DB_PASS:-qw3rty}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-admin123}"
CF_TOKEN="${CF_API_TOKEN:-tes}"

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}   Instalasi Otomatis OpenVPN Management API          ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Cek Hak Akses Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Script ini harus dijalankan sebagai root (gunakan sudo).${NC}"
    exit 1
fi

# 2. Cek OS
if [ ! -f /etc/debian_version ]; then
    echo -e "${RED}Error: Hanya mendukung sistem operasi Debian atau Ubuntu.${NC}"
    exit 1
fi

# 3. Update Sistem & Install Paket yang Dibutuhkan
echo -e "\n${YELLOW}[1/6] Menginstal dependensi sistem & PostgreSQL...${NC}"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    wget \
    tar \
    ca-certificates \
    iptables \
    iptables-persistent \
    fail2ban \
    postgresql \
    postgresql-contrib \
    lsof

# 4. Setup Database PostgreSQL
echo -e "\n${YELLOW}[2/6] Menyiapkan database PostgreSQL...${NC}"
systemctl enable --now postgresql

# Buat User & Database jika belum ada
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
echo -e "${GREEN}Database PostgreSQL berhasil dikonfigurasi.${NC}"

# 5. Siapkan Direktori Aplikasi & File Binary
echo -e "\n${YELLOW}[3/6] Menyiapkan direktori aplikasi di ${APP_DIR}...${NC}"
mkdir -p "${APP_DIR}/storage"

# Cari file binary (di current folder, /home/*, atau yang sudah ada)
if [ -f "./openvpn-api" ]; then
    cp ./openvpn-api "${APP_DIR}/openvpn-api"
elif [ -f "./jaga-vpn" ]; then
    cp ./jaga-vpn "${APP_DIR}/openvpn-api"
elif [ -f "/home/pimen/openvpn-api" ]; then
    cp /home/pimen/openvpn-api "${APP_DIR}/openvpn-api"
elif [ -f "${APP_DIR}/openvpn-api" ]; then
    echo "Menggunakan binary yang sudah ada di ${APP_DIR}/openvpn-api"
else
    echo -e "${RED}Error: File binary 'openvpn-api' atau 'jaga-vpn' tidak ditemukan!${NC}"
    echo "Silakan letakkan file binary di folder yang sama atau di /home/pimen/openvpn-api"
    exit 1
fi

chmod +x "${APP_DIR}/openvpn-api"

# 6. Buat File .env
echo -e "\n${YELLOW}[4/6] Menulis konfigurasi .env...${NC}"
cat > "${APP_DIR}/.env" <<EOF
PORT=${APP_PORT}
DATABASE_URL=postgres://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}?sslmode=disable
ADMIN_USERNAME=${ADMIN_USER}
ADMIN_PASSWORD=${ADMIN_PASS}
CF_API_TOKEN=${CF_TOKEN}
EOF
chmod 600 "${APP_DIR}/.env"

# 7. Setup Systemd Service
echo -e "\n${YELLOW}[5/6] Mendaftarkan systemd service...${NC}"

# Bebaskan port jika ada proses lama yang mengunci
lsof -ti:${APP_PORT} | xargs kill -9 2>/dev/null || true

cat > /etc/systemd/system/openvpn-api.service <<EOF
[Unit]
Description=OpenVPN Management REST API & Dashboard
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=${APP_DIR}
ExecStart=${APP_DIR}/openvpn-api
Restart=always
RestartSec=5

StandardOutput=append:${APP_DIR}/app.log
StandardError=append:${APP_DIR}/app.log

Environment=PORT=${APP_PORT}
Environment=DATABASE_URL=postgres://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}?sslmode=disable
Environment=ADMIN_USERNAME=${ADMIN_USER}
Environment=ADMIN_PASSWORD=${ADMIN_PASS}
Environment=CF_API_TOKEN=${CF_TOKEN}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openvpn-api
systemctl restart openvpn-api

# 8. Firewall (UFW) jika aktif
echo -e "\n${YELLOW}[6/6] Menyesuaikan firewall...${NC}"
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    ufw allow ${APP_PORT}/tcp comment "OpenVPN Web API/Dashboard"
    ufw allow 1194/udp comment "OpenVPN Port Default"
    ufw allow 1194/tcp comment "OpenVPN Port TCP"
    ufw reload
    echo -e "${GREEN}Firewall UFW diperbarui.${NC}"
fi

# Cek IP Publik
PUB_IP=$(curl -s -4 https://ifconfig.me || hostname -I | awk '{print $1}')

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}   Instalasi Selesai & Berhasil Dijalankan!          ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "Dashboard URL   : ${BLUE}http://${PUB_IP}:${APP_PORT}${NC}"
echo -e "Username Admin  : ${YELLOW}${ADMIN_USER}${NC}"
echo -e "Password Admin  : ${YELLOW}${ADMIN_PASS}${NC}"
echo -e "Status Service  : sudo systemctl status openvpn-api"
echo -e "Logs Service    : sudo journalctl -u openvpn-api -f"
echo -e "File Log        : ${APP_DIR}/app.log"
echo -e "======================================================\n"
