# Deployment Package - OpenVPN Management API & Dashboard

Paket deployment standalone siap pakai untuk instalasi cepat **OpenVPN Management REST API & Dashboard** pada server Linux baru (Ubuntu / Debian).

---

## 📦 Isi Folder

| File | Keterangan |
| :--- | :--- |
| `openvpn-api` | Binary executable Go yang sudah dikompilasi (termasuk static UI & API). |
| `install-server.sh` | Script bash otomatis untuk setup PostgreSQL, direktori, service systemd, dan firewall. |
| `readme.md` | Panduan instalasi dan pengoperasian. |

---

## 📋 Prasyarat Server

- **Sistem Operasi**: Ubuntu (20.04 / 22.04 / 24.04) atau Debian (11 / 12).
- **Hak Akses**: User dengan akses `root` atau `sudo`.
- **Arsitektur**: Sesuai dengan hasil kompilasi binary (misal: `amd64` atau `arm64`).

---

## 🚀 Panduan Instalasi Cepat

### 1. Upload ke Server
Dari komputer lokal, kirim file `openvpn-api` dan `install-server.sh` ke server target:

```bash
scp openvpn-api install-server.sh user@IP_SERVER_ANDA:/home/user/
```

### 2. Jalankan Script Installer di Server
Login via SSH dan jalankan installer dengan hak akses `root`:

```bash
ssh user@IP_SERVER_ANDA

# Berikan izin eksekusi dan jalankan script
chmod +x install-server.sh
sudo bash install-server.sh
```

### 3. Selesai & Akses Dashboard
Setelah script selesai berjalan, buka browser dan akses:
- **URL**: `http://<IP_SERVER_ANDA>:8000`
- **Username Default**: `admin`
- **Password Default**: `admin123`

---

## ⚙️ Detail Konfigurasi Sistem

Script `install-server.sh` secara otomatis melakukan:
1. Instalasi paket dependensi: `postgresql`, `iptables`, `iptables-persistent`, `fail2ban`, `lsof`, `curl`, `wget`, `tar`.
2. Pembuatan database PostgreSQL (`appdb`) dan user (`appuser` / password: `qw3rty`).
3. Penempatan binary di `/opt/openvpn-api/openvpn-api`.
4. Konfigurasi file `.env` di `/opt/openvpn-api/.env`.
5. Pendaftaran & aktivasi daemon systemd `/etc/systemd/system/openvpn-api.service`.
6. Pembukaan port firewall (UFW): `8000/tcp`, `1194/udp`, `1194/tcp`.

---

## 🛠️ Perintah Pengelolaan (Cheat Sheet)

### Cek Status Service
```bash
sudo systemctl status openvpn-api
```

### Restart Service
```bash
sudo systemctl restart openvpn-api
```

### Stop / Start Service
```bash
sudo systemctl stop openvpn-api
sudo systemctl start openvpn-api
```

### Melihat Log Aplikasi
```bash
# Log realtime via journalctl
sudo journalctl -u openvpn-api -f

# Atau via file app.log
tail -f /opt/openvpn-api/app.log
```

### Reset Password Admin (CLI)
Jika Anda lupa password login dashboard:
```bash
cd /opt/openvpn-api
sudo ./openvpn-api -reset-password-user admin -reset-password-pass password_baru_anda
```

---

## 🔄 Cara Update Binary di Masa Depan

Jika ada pembaruan kode aplikasi:
1. Build binary baru di komputer pengembang:
   ```bash
   CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o openvpn-api main.go
   ```
2. Upload binary baru ke server:
   ```bash
   scp openvpn-api user@IP_SERVER_ANDA:/home/user/
   ```
3. Timpa binary lama dan restart service:
   ```bash
   sudo cp /home/user/openvpn-api /opt/openvpn-api/openvpn-api
   sudo chmod +x /opt/openvpn-api/openvpn-api
   sudo systemctl restart openvpn-api
   ```
