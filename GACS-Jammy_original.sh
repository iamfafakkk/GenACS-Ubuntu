#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to display spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "${CYAN} [%c]  ${NC}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to run command with progress
run_command() {
    local cmd="$1"
    local msg="$2"
    printf "${YELLOW}%-50s${NC}" "$msg..."
    eval "$cmd" > /dev/null 2>&1 &
    spinner $!
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${RED}Failed${NC}"
        exit 1
    fi
}

# Print banner
print_banner() {
	echo -e "${BLUE}${BOLD}"
	echo "   ____    _    ____ ____     ____            _       _   "
	echo "  / ___|  / \  / ___/ ___|   / ___|  ___ _ __(_)_ __ | |_ "
	echo " | |  _  / _ \| |   \___ \   \___ \ / __| '__| | '_ \| __|"
	echo " | |_| |/ ___ \ |___ ___) |   ___) | (__| |  | | |_) | |_ "
	echo "  \____/_/   \_\____|____/   |____/ \___|_|  |_| .__/ \__|"
	echo "                                               |_|        "
	echo ""
	echo "                  --- Ubuntu 22.04 / 24.04 ---"
	echo "                  --- By Mostech ---"
	echo -e "${NC}"
}

# Check for root access
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Determine service user
if [ -n "$SUDO_USER" ]; then
    GENIEACS_USER="$SUDO_USER"
else
    GENIEACS_USER=$(whoami)
fi
GENIEACS_GROUP=$(id -gn "$GENIEACS_USER")

echo -e "${MAGENTA}Services will run as user: ${BOLD}$GENIEACS_USER${NC}"

# Check Ubuntu version
if [ "$(lsb_release -cs)" != "jammy" ] && [ "$(lsb_release -cs)" != "noble" ]; then
    echo -e "${RED}This script only supports Ubuntu 22.04 (Jammy) and Ubuntu 24.04 (Noble)${NC}"
    exit 1
fi

# Print banner
print_banner

# Main installation process
total_steps=25
current_step=0

echo -e "\n${MAGENTA}${BOLD}Starting GenieACS Installation Process${NC}\n"

# run_command "apt-get update -y" "Updating system ($(( ++current_step ))/$total_steps)"

run_command "[ -f /etc/needrestart/needrestart.conf ] && sed -i 's/#\$nrconf{restart} = '"'"'i'"'"';/\$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf || echo 'needrestart config not found, skipping'" "Configuring needrestart ($(( ++current_step ))/$total_steps)"

run_command "dpkg -s nodejs &> /dev/null || apt install -y nodejs" "Installing NodeJS ($(( ++current_step ))/$total_steps)"

run_command "dpkg -s npm &> /dev/null || apt install -y npm" "Installing NPM ($(( ++current_step ))/$total_steps)"

# MongoDB Installation
UBUNTU_CODENAME=$(lsb_release -cs)
MONGO_REPO_CODENAME=$UBUNTU_CODENAME
# Use jammy repo for noble if noble repo is not explicitly available/stable yet for the chosen version, 
# but MongoDB 7.0+ should support newer ssl. For now, we will use the dynamic codename.
# If on Noble, we might need to fallback to jammy repo if noble specific one is missing, 
# but usually MongoDB adds support. 
# Safe bet for now: Use 'jammy' repo for both if necessary, but let's try strict matching first.
# Actually, widely used approach for Noble is using Jammy repo for Mongo 7.0.
if [ "$UBUNTU_CODENAME" == "noble" ]; then
    MONGO_REPO_CODENAME="jammy"
fi

run_command "curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg" "Adding MongoDB key ($(( ++current_step ))/$total_steps)"

run_command "echo \"deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $MONGO_REPO_CODENAME/mongodb-org/7.0 multiverse\" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list" "Adding MongoDB repository ($(( ++current_step ))/$total_steps)"

run_command "apt-get update -y" "Updating package list ($(( ++current_step ))/$total_steps)"

run_command "dpkg -s mongodb-org &> /dev/null || apt-get install -y mongodb-org" "Installing MongoDB ($(( ++current_step ))/$total_steps)"

# run_command "apt-get upgrade -y" "Upgrading system ($(( ++current_step ))/$total_steps)"

run_command "systemctl start mongod" "Starting MongoDB service ($(( ++current_step ))/$total_steps)"

run_command "systemctl enable mongod" "Enabling MongoDB service ($(( ++current_step ))/$total_steps)"

run_command "npm list -g genieacs &> /dev/null || npm install -g genieacs@1.2.13" "Installing GenieACS ($(( ++current_step ))/$total_steps)"

# run_command "id -u genieacs &>/dev/null || useradd --system --no-create-home --user-group genieacs" "Creating GenieACS user ($(( ++current_step ))/$total_steps)"

run_command "mkdir -p /opt/genieacs/ext && chown $GENIEACS_USER:$GENIEACS_GROUP /opt/genieacs/ext" "Creating GenieACS directories ($(( ++current_step ))/$total_steps)"

# Create genieacs.env file
cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
EOF
echo -e "${YELLOW}Creating genieacs.env file ($(( ++current_step ))/$total_steps)${NC}... ${GREEN}Done${NC}"

run_command "node -e \"console.log('GENIEACS_UI_JWT_SECRET=' + require('crypto').randomBytes(128).toString('hex'))\" >> /opt/genieacs/genieacs.env" "Generating JWT secret ($(( ++current_step ))/$total_steps)"

run_command "chown $GENIEACS_USER:$GENIEACS_GROUP /opt/genieacs/genieacs.env && chmod 600 /opt/genieacs/genieacs.env" "Setting genieacs.env permissions ($(( ++current_step ))/$total_steps)"

run_command "mkdir -p /var/log/genieacs && chown $GENIEACS_USER:$GENIEACS_GROUP /var/log/genieacs" "Creating log directory ($(( ++current_step ))/$total_steps)"

# Create systemd service files
for service in cwmp nbi fs ui; do
    cat << EOF > /etc/systemd/system/genieacs-$service.service
[Unit]
Description=GenieACS $service
After=network.target

[Service]
User=$GENIEACS_USER
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/local/bin/genieacs-$service

[Install]
WantedBy=default.target
EOF
    echo -e "${YELLOW}Creating genieacs-$service service file ($(( ++current_step ))/$total_steps)${NC}... ${GREEN}Done${NC}"
done

# Create logrotate configuration
cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF
echo -e "${YELLOW}Creating logrotate configuration ($(( ++current_step ))/$total_steps)${NC}... ${GREEN}Done${NC}"

# Enable and start services
for service in cwmp nbi fs ui; do
    run_command "systemctl enable genieacs-$service && systemctl start genieacs-$service" "Enabling and starting genieacs-$service ($(( ++current_step ))/$total_steps)"
done

# Check services status
echo -e "\n${MAGENTA}${BOLD}Checking services status:${NC}"
for service in mongod genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui; do
    status=$(systemctl is-active $service)
    if [ "$status" = "active" ]; then
        echo -e "${GREEN}✔ $service is running${NC}"
    else
        echo -e "${RED}✘ $service is not running${NC}"
    fi
done

echo -e "\n${GREEN}${BOLD}Script execution completed successfully!${NC}"
