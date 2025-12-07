#!/bin/bash
# INI ADALAH VERSI COMMAND LINE BY LINE (Tanpa fungsi otomatisasi yang rumit)
# Anda bisa menjalankannya per blok atau copy-paste.

# ==========================================
# BAGIAN 1: SYSTEM & DEPENDENCIES
# !!! PERHATIAN: BAGIAN INI WAJIB AKSES ROOT (sudo) !!!
# ==========================================

# 1. Konfigurasi needrestart (Optional) - [BUTUH ROOT]
[ -f /etc/needrestart/needrestart.conf ] && sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

# 2. Install Node.js & NPM - [BUTUH ROOT]
sudo apt install -y nodejs npm

# 3. Setup MongoDB Repository - [BUTUH ROOT]
# (Khusus CPU Non-AVX: Menggunakan MongoDB 4.4)
# Install libssl1.1 (Dependency untuk Mongo 4.4 di Ubuntu 22.04+)
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb
rm libssl1.1_1.1.1f-1ubuntu2_amd64.deb

# Download key
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/mongodb-server-4.4.gpg

# Add repo (Menggunakan 'focal' karena Mongo 4.4 hanya support sampai focal, tapi compatible)
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

# 4. Install MongoDB - [BUTUH ROOT]
sudo apt-get update -y
sudo apt-get install -y mongodb-org

# 5. Start MongoDB & Pin Version - [BUTUH ROOT]
sudo systemctl start mongod
sudo systemctl enable mongod
sudo systemctl status mongod
mongod --version

# Mencegah update otomatis ke versi yang butuh AVX
echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections
echo "mongodb-org-shell hold" | sudo dpkg --set-selections
echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
echo "mongodb-org-tools hold" | sudo dpkg --set-selections


# ==========================================
# BAGIAN 2: INSTALL GENIEACS
# !!! PERHATIAN: BAGIAN INI DIJALANKAN SEBAGAI USER BIASA (acs) !!!
# (Jangan gunakan root untuk npm install)
# ==========================================
# Perintah di bawah ini dijalankan sebagai user 'acs'.
# Kami menggunakan 'su - acs -c' agar bisa dijalankan dari script root ini,
# tapi jika Anda manual, login dulu: su - acs

# 6. Buat direktori aplikasi - [BUTUH ROOT]
# (Karena kita root, kita buatkan dulu lalu chown, atau user acs yang buat sendiri)
sudo mkdir -p /home/acs/htdocs/acs.perwiramedia.com
sudo chown -R acs:acs /home/acs/htdocs/acs.perwiramedia.com

# 7. Install GenieACS (sebagai user acs) - [BUTUH USER: acs]
sudo su - acs -c 'cd /home/acs/htdocs/acs.perwiramedia.com && npm install genieacs@1.2.13'

# 8. Buat folder extensions - [BUTUH USER: acs]
sudo su - acs -c 'mkdir -p /home/acs/htdocs/acs.perwiramedia.com/ext'

# 9. Buat file konfigurasi genieacs.env - [BUTUH ROOT]
# Kita tulis file ini sebagai root lalu kita berikan permission ke acs
sudo bash -c 'cat << EOF > /home/acs/htdocs/acs.perwiramedia.com/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/home/acs/htdocs/acs.perwiramedia.com/ext
EOF'

# 10. Generate JWT Secret dan masukkan ke env - [BISA ROOT/USER]
# (Jalankan node sebagai acs atau root tidak masalah asal outputnya benar, kita fix permission nanti)
# sudo bash -c "node -e \"console.log('GENIEACS_UI_JWT_SECRET=' + require('crypto').randomBytes(128).toString('hex'))\" >> /home/acs/htdocs/acs.perwiramedia.com/genieacs.env"
sudo bash -c "/home/acs/.nvm/versions/node/v22.21.1/bin/node -e \"console.log('GENIEACS_UI_JWT_SECRET=' + require('crypto').randomBytes(128).toString('hex'))\" >> /home/acs/htdocs/acs.perwiramedia.com/genieacs.env"

# 11. Fix Permission genieacs.env - [BUTUH ROOT]
sudo chown acs:acs /home/acs/htdocs/acs.perwiramedia.com/genieacs.env
sudo chmod 600 /home/acs/htdocs/acs.perwiramedia.com/genieacs.env


# ==========================================
# BAGIAN 3: SYSTEM SERVICES
# !!! PERHATIAN: KEMBALI MENGGUNAKAN AKSES ROOT (sudo) !!!
# ==========================================

# 12. Buat Log Directory - [BUTUH ROOT]
sudo mkdir -p /var/log/genieacs
sudo chown acs:acs /var/log/genieacs

# 13. Create Systemd Services - [BUTUH ROOT]
# Perhatikan path ExecStart mengarah ke local node_modules

# Service: CWMP
sudo bash -c 'cat << EOF > /etc/systemd/system/genieacs-cwmp.service
[Unit]
Description=GenieACS CWMP
After=network.target

[Service]
User=acs
WorkingDirectory=/home/acs/htdocs/acs.perwiramedia.com
EnvironmentFile=/home/acs/htdocs/acs.perwiramedia.com/genieacs.env
ExecStart=/home/acs/.nvm/versions/node/v22.21.1/bin/node /home/acs/htdocs/acs.perwiramedia.com/node_modules/.bin/genieacs-cwmp
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF'


# Service: NBI
sudo bash -c 'cat << EOF > /etc/systemd/system/genieacs-nbi.service
[Unit]
Description=GenieACS NBI
After=network.target

[Service]
User=acs
WorkingDirectory=/home/acs/htdocs/acs.perwiramedia.com
EnvironmentFile=/home/acs/htdocs/acs.perwiramedia.com/genieacs.env
ExecStart=/home/acs/.nvm/versions/node/v22.21.1/bin/node /home/acs/htdocs/acs.perwiramedia.com/node_modules/.bin/genieacs-nbi
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF'

# Service: FS
sudo bash -c 'cat << EOF > /etc/systemd/system/genieacs-fs.service
[Unit]
Description=GenieACS FS
After=network.target

[Service]
User=acs
WorkingDirectory=/home/acs/htdocs/acs.perwiramedia.com
EnvironmentFile=/home/acs/htdocs/acs.perwiramedia.com/genieacs.env
ExecStart=/home/acs/.nvm/versions/node/v22.21.1/bin/node /home/acs/htdocs/acs.perwiramedia.com/node_modules/.bin/genieacs-fs
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF'


# Service: UI
sudo bash -c 'cat << EOF > /etc/systemd/system/genieacs-ui.service
[Unit]
Description=GenieACS UI
After=network.target

[Service]
User=acs
WorkingDirectory=/home/acs/htdocs/acs.perwiramedia.com
EnvironmentFile=/home/acs/htdocs/acs.perwiramedia.com/genieacs.env
ExecStart=/home/acs/.nvm/versions/node/v22.21.1/bin/node /home/acs/htdocs/acs.perwiramedia.com/node_modules/.bin/genieacs-ui
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF'


# 14. Logrotate
sudo bash -c 'cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF'

# 15. Start Services
sudo systemctl daemon-reload
sudo systemctl enable genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui
sudo systemctl restart genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui

# 16. Check Status
sudo systemctl status genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui --no-pager

#bayarinternet
#Segamas20251!