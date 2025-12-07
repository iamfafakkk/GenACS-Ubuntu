#!/bin/bash
# INI ADALAH VERSI COMMAND LINE BY LINE (Tanpa fungsi otomatisasi yang rumit)
# Anda bisa menjalankannya per blok atau copy-paste.

# ==========================================
# BAGIAN 1: SYSTEM & DEPENDENCIES
# !!! PERHATIAN: BAGIAN INI WAJIB AKSES ROOT (sudo) !!!
# ==========================================

# 1. Konfigurasi needrestart (Optional) - [BUTUH ROOT]
[ -f /etc/needrestart/needrestart.conf ] && sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

# 2. Install Node.js & NPM - [BUTUH ROOT]
apt install -y nodejs npm

# 3. Setup MongoDB Repository - [BUTUH ROOT]
# Download key
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor --yes -o /usr/share/keyrings/mongodb-server-7.0.gpg

# Add repo (menggunakan 'jammy' untuk kompatibilitas 22.04/24.04)
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# 4. Install MongoDB - [BUTUH ROOT]
apt-get update -y
apt-get install -y mongodb-org

# 5. Start MongoDB - [BUTUH ROOT]
systemctl start mongod
systemctl enable mongod


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
mkdir -p /home/acs/htdocs/acs.perwiramedia.com
chown -R acs:acs /home/acs/htdocs/acs.perwiramedia.com

# 7. Install GenieACS (sebagai user acs) - [BUTUH USER: acs]
su - acs -c 'cd /home/acs/htdocs/acs.perwiramedia.com && npm install genieacs@1.2.13'

# 8. Buat folder extensions - [BUTUH USER: acs]
su - acs -c 'mkdir -p /home/acs/htdocs/acs.perwiramedia.com/ext'

# 9. Buat file konfigurasi genieacs.env - [BUTUH ROOT]
# Kita tulis file ini sebagai root lalu kita berikan permission ke acs
cat << EOF > /home/acs/htdocs/acs.perwiramedia.com/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/home/acs/htdocs/acs.perwiramedia.com/ext
EOF

# 10. Generate JWT Secret dan masukkan ke env - [BISA ROOT/USER]
# (Jalankan node sebagai acs atau root tidak masalah asal outputnya benar, kita fix permission nanti)
node -e "console.log('GENIEACS_UI_JWT_SECRET=' + require('crypto').randomBytes(128).toString('hex'))" >> /home/acs/htdocs/acs.perwiramedia.com/genieacs.env

# 11. Fix Permission genieacs.env - [BUTUH ROOT]
chown acs:acs /home/acs/htdocs/acs.perwiramedia.com/genieacs.env
chmod 600 /home/acs/htdocs/acs.perwiramedia.com/genieacs.env


# ==========================================
# BAGIAN 3: SYSTEM SERVICES
# !!! PERHATIAN: KEMBALI MENGGUNAKAN AKSES ROOT (sudo) !!!
# ==========================================

# 12. Buat Log Directory - [BUTUH ROOT]
mkdir -p /var/log/genieacs
chown acs:acs /var/log/genieacs

# 13. Create Systemd Services - [BUTUH ROOT]
# Perhatikan path ExecStart mengarah ke local node_modules

# Service: CWMP
cat << EOF > /etc/systemd/system/genieacs-cwmp.service
[Unit]
Description=GenieACS cwmp
After=network.target

[Service]
User=acs
EnvironmentFile=/home/acs/htdocs/acs.perwiramedia.com/genieacs.env
ExecStart=/home/acs/htdocs/acs.perwiramedia.com/node_modules/.bin/genieacs-cwmp

[Install]
WantedBy=default.target
EOF

# Service: NBI
cat << EOF > /etc/systemd/system/genieacs-nbi.service
[Unit]
Description=GenieACS nbi
After=network.target

[Service]
User=acs
EnvironmentFile=/home/acs/htdocs/acs.perwiramedia.com/genieacs.env
ExecStart=/home/acs/htdocs/acs.perwiramedia.com/node_modules/.bin/genieacs-nbi

[Install]
WantedBy=default.target
EOF

# Service: FS
cat << EOF > /etc/systemd/system/genieacs-fs.service
[Unit]
Description=GenieACS fs
After=network.target

[Service]
User=acs
EnvironmentFile=/home/acs/htdocs/acs.perwiramedia.com/genieacs.env
ExecStart=/home/acs/htdocs/acs.perwiramedia.com/node_modules/.bin/genieacs-fs

[Install]
WantedBy=default.target
EOF

# Service: UI
cat << EOF > /etc/systemd/system/genieacs-ui.service
[Unit]
Description=GenieACS ui
After=network.target

[Service]
User=acs
EnvironmentFile=/home/acs/htdocs/acs.perwiramedia.com/genieacs.env
ExecStart=/home/acs/htdocs/acs.perwiramedia.com/node_modules/.bin/genieacs-ui

[Install]
WantedBy=default.target
EOF

# 14. Logrotate
cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF

# 15. Start Services
systemctl daemon-reload
systemctl enable genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui
systemctl restart genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui

# 16. Check Status
systemctl status genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui --no-pager
