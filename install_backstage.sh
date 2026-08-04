#!/bin/bash
# ==============================================================================
# Spotify Backstage Developer Portal Automated Installation Script
# Target OS: Amazon Linux 2023 / RHEL / CentOS / Ubuntu
# Installs Node.js 20 LTS, Yarn, Python3, Docker, bootstraps Backstage app in
# /opt/backstage, configures network bindings, and sets up a Systemd service.
# Ports: Frontend (7000), Backend API (7007)
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Spotify Backstage Developer Portal Installation"
echo "=========================================================================="

# 1. Update DNF package manager & install build prerequisites
echo "--> Updating package manager and installing build tools..."
if command -v dnf &> /dev/null; then
    sudo dnf update -y
    sudo dnf install -y git wget gcc-c++ make python3 python3-pip tar
elif command -v apt-get &> /dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y git wget curl build-essential python3 python3-pip tar
fi

# 2. Install Node.js 20 LTS & Yarn
echo "--> Checking Node.js installation..."
NODE_VER=""
if command -v node &> /dev/null; then
    NODE_VER=$(node -v | cut -d'.' -f1 | sed 's/v//')
fi

if [ -z "$NODE_VER" ] || [ "$NODE_VER" -lt 18 ]; then
    echo "--> Installing Node.js 20 LTS..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y nodejs20 npm 2>/dev/null || {
            echo "--> Setting up NodeSource Node.js 20 repository..."
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo dnf install -y nodejs
        }
    elif command -v apt-get &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
        sudo apt-get install -y nodejs
    fi
fi

echo "--> Verified Node.js Version: $(node -v)"

echo "--> Installing Yarn package manager globally..."
sudo npm install -g yarn corepack 2>/dev/null || sudo npm install -g yarn

echo "--> Verified Yarn Version: $(yarn -v)"

# 3. Ensure Docker is installed and running (Required for TechDocs & Containerized Plugins)
echo "--> Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "--> Docker not found. Installing Docker Engine..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y docker
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y docker.io
    fi
fi

echo "--> Enabling and starting Docker service..."
sudo systemctl daemon-reload 2>/dev/null || true
sudo systemctl enable --now docker 2>/dev/null || true
sudo usermod -aG docker $USER 2>/dev/null || true

# 4. Bootstrap Spotify Backstage App in /opt/backstage
TARGET_DIR="/opt/backstage"

if [ ! -f "${TARGET_DIR}/package.json" ]; then
    echo "--> Bootstrapping new Spotify Backstage application in ${TARGET_DIR}..."
    sudo mkdir -p /opt
    sudo chown -R $USER:$USER /opt 2>/dev/null || true

    cd /opt
    # Run @backstage/create-app non-interactively
    echo "backstage" | npx --yes @backstage/create-app@latest --skip-install
fi

cd "${TARGET_DIR}"
echo "--> Installing & syncing Node.js dependencies using Yarn (this may take 2-3 minutes)..."
yarn install

# 5. Configure app-config.yaml for external network access (Public IP)
PUBLIC_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost')

echo "--> Configuring network endpoints in app-config.yaml (Public IP: ${PUBLIC_IP})..."

if [ -f "${TARGET_DIR}/app-config.yaml" ]; then
    if [ ! -f "${TARGET_DIR}/app-config.yaml.bak" ]; then
        cp "${TARGET_DIR}/app-config.yaml" "${TARGET_DIR}/app-config.yaml.bak"
    fi

    # Replace localhost/3000 with Public IP and Port 7000 to prevent conflict with Grafana (Port 3000)
    sed -i "s|baseUrl: http://localhost:3000|baseUrl: http://${PUBLIC_IP}:7000|g" "${TARGET_DIR}/app-config.yaml"
    sed -i "s|baseUrl: http://${PUBLIC_IP}:3000|baseUrl: http://${PUBLIC_IP}:7000|g" "${TARGET_DIR}/app-config.yaml"
    sed -i "s|baseUrl: http://localhost:7007|baseUrl: http://${PUBLIC_IP}:7007|g" "${TARGET_DIR}/app-config.yaml"

    # Configure backend host binding to 0.0.0.0 so backend listens on all network interfaces
    if grep -q "listen:" "${TARGET_DIR}/app-config.yaml"; then
        if ! grep -q "host: 0.0.0.0" "${TARGET_DIR}/app-config.yaml"; then
            sed -i '/listen:/a \    host: 0.0.0.0' "${TARGET_DIR}/app-config.yaml"
        fi
    fi
fi

# 6. Configure Systemd Service for Backstage
echo "--> Setting up Systemd service for Spotify Backstage..."

YARN_PATH=$(which yarn || echo '/usr/local/bin/yarn')
NODE_PATH=$(which node || echo '/usr/bin/node')
NODE_BIN_DIR=$(dirname "$NODE_PATH")

cat << EOF | sudo tee /etc/systemd/system/backstage.service > /dev/null
[Unit]
Description=Spotify Backstage Developer Portal Service
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=${TARGET_DIR}
ExecStart=${YARN_PATH} dev
Restart=always
RestartSec=10
Environment=NODE_ENV=development
Environment=PORT=7000
Environment=HOST=0.0.0.0
Environment=PATH=${NODE_BIN_DIR}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

# 7. Start Backstage Service
echo "--> Enabling and starting Backstage systemd service..."
sudo systemctl daemon-reload
sudo systemctl enable backstage
sudo systemctl restart backstage

echo ""
echo "=========================================================================="
echo " 🎉 Spotify Backstage Developer Portal Installed & Started Successfully!"
echo "=========================================================================="
echo " Access Backstage Web UI at:     http://${PUBLIC_IP}:7000"
echo " Access Backstage Backend API:   http://${PUBLIC_IP}:7007"
echo " Application Directory:          ${TARGET_DIR}"
echo " Configuration File:             ${TARGET_DIR}/app-config.yaml"
echo "--------------------------------------------------------------------------"
echo " ⚠️ AWS EC2 Security Group Requirement:"
echo "   Ensure Inbound Rules allow Custom TCP Ports 7000 and 7007 from 0.0.0.0/0"
echo "--------------------------------------------------------------------------"
echo " Management Commands:"
echo "   - View Logs:    sudo journalctl -u backstage.service -f"
echo "   - Check Status: sudo systemctl status backstage.service"
echo "   - Restart Service: sudo systemctl restart backstage.service"
echo "=========================================================================="
