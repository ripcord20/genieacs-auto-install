#!/bin/bash

set -e

### Step 1: Update & Install Dependencies ###
echo "[1/9] Updating and installing dependencies..."
sudo apt update
sudo apt install -y curl mongodb nodejs npm

### Step 2: Install Node.js 14.x ###
echo "[2/9] Installing Node.js 14.x..."
cd ~
curl -fsSL https://deb.nodesource.com/setup_14.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt install -y nodejs

### Step 3: Setup MongoDB Users ###
echo "[3/9] Configuring MongoDB users..."
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

### Step 4: Install GenieACS ###
echo "[4/9] Installing GenieACS..."
sudo npm install -g genieacs@1.2.9

### Step 5: Create Directories and User ###
echo "[5/9] Creating directories and user..."
sudo useradd --system --no-create-home --user-group genieacs || true
sudo mkdir -p /opt/genieacs/ext
sudo chown -R genieacs:genieacs /opt/genieacs

### Step 6: Create genieacs.env file ###
echo "[6/9] Creating environment file..."
cat <<EOL | sudo tee /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
EOL

node -e "require('crypto').randomBytes(128).toString('hex')" | sudo tee -a /opt/genieacs/genieacs.env

### Step 7: Create systemd service files ###
echo "[7/9] Creating systemd service files..."
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
WantedBy=default.target
EOL

done

### Step 8: Setup logrotate ###
echo "[8/9] Configuring logrotate..."
cat <<EOL | sudo tee /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
  daily
  rotate 30
  compress
  delaycompress
  dateext
}
EOL

### Step 9: Enable and Start Services ###
echo "[9/9] Enabling and starting services..."
for svc in cwmp nbi fs ui; do
  sudo systemctl enable genieacs-$svc
  sudo systemctl start genieacs-$svc
  sudo systemctl status genieacs-$svc --no-pager
  echo "[OK] genieacs-$svc started"
done

echo "\n✅ GenieACS installation and configuration complete!"
echo "🌐 Akses UI di: http://<server-ip>:3000"
