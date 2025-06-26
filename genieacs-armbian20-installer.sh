#!/bin/bash
set -e

echo "[1/9] Update & install dependencies..."
sudo apt update
sudo apt install -y curl gnupg build-essential git

echo "[2/9] Install Node.js 14.x (LTS) for ARM64..."
curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt install -y nodejs

echo "[3/9] Install MongoDB 4.4 for Armbian..."
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb [ arch=arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl enable mongod
sudo systemctl start mongod

echo "[4/9] Install GenieACS 1.2.9..."
sudo npm install -g genieacs@1.2.9

echo "[5/9] Setup direktori & user..."
sudo useradd --system --no-create-home --user-group genieacs || true
sudo mkdir -p /opt/genieacs/ext
sudo chown -R genieacs:genieacs /opt/genieacs

echo "[6/9] Buat dan pasang file ENV + JWT secret..."
JWT=$(openssl rand -hex 32)
cat <<EOF | sudo tee /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
UI_JWT_SECRET=$JWT
EOF

sudo mkdir -p /var/log/genieacs
sudo chown -R genieacs:genieacs /var/log/genieacs

echo "[7/9] Install jsonwebtoken untuk generate token login..."
sudo npm install -g jsonwebtoken@8

echo "[8/9] Buat service systemd untuk semua modul GenieACS..."
for svc in cwmp nbi fs ui; do
sudo tee /etc/systemd/system/genieacs-$svc.service > /dev/null <<EOF
[Unit]
Description=GenieACS ${svc^^}
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/bin/bash -c 'source /opt/genieacs/genieacs.env && exec /usr/bin/genieacs-$svc'
Restart=always

[Install]
WantedBy=multi-user.target
EOF
done

echo "[9/9] Enable & start semua service GenieACS..."
sudo systemctl daemon-reload
for svc in cwmp nbi fs ui; do
  sudo systemctl enable genieacs-$svc
  sudo systemctl restart genieacs-$svc
done

echo ""
echo "🎉 INSTALASI SELESAI!"
echo "🌐 Buka: http://<IP-STB-KAMU>:3000"
echo ""
echo "🔐 Token login JWT kamu:"
node -e "console.log(require('jsonwebtoken').sign({}, '$JWT'))"
