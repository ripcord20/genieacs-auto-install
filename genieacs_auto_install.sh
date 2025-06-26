#!/bin/bash
set -e

echo "[1/10] Update system & install dependencies..."
sudo apt update
sudo apt install -y curl gnupg build-essential mongodb nodejs npm

echo "[2/10] Pastikan MongoDB berjalan..."
sudo systemctl enable mongodb
sudo systemctl start mongodb

echo "[3/10] Konfigurasi user MongoDB..."
mongo <<EOF
use admin
db.createUser({
  user: "admin",
  pwd: "admin",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "dbAdminAnyDatabase", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" }
  ]
})
use genieacs
db.createUser({
  user: "genie",
  pwd: "genie",
  roles: [ "readWrite" ]
})
EOF

echo "[4/10] Install Node.js 14.x..."
curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt install -y nodejs

echo "[5/10] Install GenieACS v1.2.9..."
sudo npm install -g genieacs@1.2.9

echo "[6/10] Setup direktori dan user..."
sudo useradd --system --no-create-home --user-group genieacs || true
sudo mkdir -p /opt/genieacs/ext
sudo chown -R genieacs:genieacs /opt/genieacs

echo "[7/10] Membuat environment file..."
cat <<EOL | sudo tee /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
EOL

node -e "require('crypto').randomBytes(128).toString('hex')" | sudo tee -a /opt/genieacs/genieacs.env

echo "[8/10] Membuat direktori log GenieACS..."
sudo mkdir -p /var/log/genieacs
sudo chown -R genieacs:genieacs /var/log/genieacs

echo "[9/10] Membuat service systemd..."
for svc in cwmp nbi fs ui; do
  sudo bash -c "cat > /etc/systemd/system/genieacs-$svc.service" <<EOL
[Unit]
Description=GenieACS ${svc^^}
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$svc

[Install]
WantedBy=multi-user.target
EOL
done

echo "[10/10] Konfigurasi logrotate..."
cat <<EOL | sudo tee /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
  daily
  rotate 30
  compress
  delaycompress
  dateext
}
EOL

echo "🔄 Restart semua service GenieACS..."
sudo systemctl daemon-reexec
for svc in cwmp nbi fs ui; do
  sudo systemctl enable genieacs-$svc
  sudo systemctl restart genieacs-$svc
  sudo systemctl status genieacs-$svc --no-pager
done

echo ""
echo "✅ GenieACS berhasil di-install dan dijalankan di Ubuntu 20.04!"
echo "🌐 Buka: http://<IP-SERVER>:3000 di browser kamu."
