#!/bin/bash
# ==============================================================================
# Spotify Backstage Developer Portal Automated Installation Script
# Target OS: Amazon Linux 2023 / RHEL / CentOS / Ubuntu
# Installs Node.js 22/20, Yarn, Corepack, Python3, Docker, bootstraps Backstage,
# configures network endpoints & port 7000, and sets up a Systemd service.
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
    sudo dnf install -y git wget gcc gcc-c++ make python3 python3-pip python3-devel sqlite-devel libffi-devel tar gzip docker nodejs22 2>/dev/null || \
    sudo dnf install -y git wget gcc gcc-c++ make python3 python3-pip python3-devel sqlite-devel libffi-devel tar gzip docker nodejs20 2>/dev/null || \
    sudo dnf install -y git wget gcc gcc-c++ make python3 python3-pip python3-devel sqlite-devel libffi-devel tar gzip docker nodejs
elif command -v apt-get &> /dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y git wget curl build-essential python3 python3-pip python3-dev libsqlite3-dev libffi-dev tar gzip docker.io
fi

# 2. Configure Node.js, Corepack & Yarn
echo "--> Verified Node.js Version: $(node -v 2>/dev/null || echo 'Not installed')"

echo "--> Enabling Corepack and activating Yarn..."
sudo corepack enable 2>/dev/null || true
corepack prepare yarn@stable --activate 2>/dev/null || sudo npm install -g yarn

echo "--> Verified Yarn Version: $(yarn -v 2>/dev/null || echo 'Not installed')"

# 3. Increase Node memory allocation to prevent out-of-memory during builds
export NODE_OPTIONS="--max-old-space-size=4096"

# 4. Enable and Start Docker Service
echo "--> Enabling and starting Docker service..."
sudo systemctl daemon-reload 2>/dev/null || true
sudo systemctl enable --now docker 2>/dev/null || true
sudo usermod -aG docker $USER 2>/dev/null || sudo usermod -aG docker ec2-user 2>/dev/null || true

# 5. Bootstrap Spotify Backstage App in /opt/backstage
TARGET_DIR="/opt/backstage"

if [ ! -f "${TARGET_DIR}/package.json" ]; then
    echo "--> Bootstrapping new Spotify Backstage application in ${TARGET_DIR}..."
    sudo mkdir -p /opt
    sudo chown -R $USER:$USER /opt 2>/dev/null || sudo chown -R ec2-user:ec2-user /opt 2>/dev/null || true

    cd /opt
    # Create Backstage app
    echo "backstage" | npx --yes @backstage/create-app@latest
fi

cd "${TARGET_DIR}"
sudo chown -R $USER:$USER "${TARGET_DIR}" 2>/dev/null || sudo chown -R ec2-user:ec2-user "${TARGET_DIR}" 2>/dev/null || true

echo "--> Syncing Node.js dependencies using Yarn..."
yarn install

# 6. Configure app-config.yaml for external network access (Public IP & Port 7000)
PUBLIC_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost')

echo "--> Configuring network endpoints in app-config.yaml (Public IP: ${PUBLIC_IP}, Port: 7000)..."

if [ -f "${TARGET_DIR}/app-config.yaml" ]; then
    if [ ! -f "${TARGET_DIR}/app-config.yaml.bak" ]; then
        cp "${TARGET_DIR}/app-config.yaml" "${TARGET_DIR}/app-config.yaml.bak"
    else
        # Restore full original template config before modifying
        cp "${TARGET_DIR}/app-config.yaml.bak" "${TARGET_DIR}/app-config.yaml"
    fi

    # Replace localhost with Public IP and Port 7000 to prevent conflict with Grafana (Port 3000)
    sed -i "s|baseUrl: http://localhost:3000|baseUrl: http://${PUBLIC_IP}:7000|g" "${TARGET_DIR}/app-config.yaml"
    sed -i "s|baseUrl: http://${PUBLIC_IP}:3000|baseUrl: http://${PUBLIC_IP}:7000|g" "${TARGET_DIR}/app-config.yaml"
    sed -i "s|baseUrl: http://localhost:7007|baseUrl: http://${PUBLIC_IP}:7007|g" "${TARGET_DIR}/app-config.yaml"

    # Configure frontend listen block (host 0.0.0.0 & port 7000)
    if ! grep -A 5 "^app:" "${TARGET_DIR}/app-config.yaml" | grep -q "listen:"; then
        sed -i '/^app:/a \  listen:\n    host: 0.0.0.0\n    port: 7000' "${TARGET_DIR}/app-config.yaml"
    fi

    # Configure backend listen block (host 0.0.0.0)
    if ! grep -A 5 "^backend:" "${TARGET_DIR}/app-config.yaml" | grep -q "host: 0.0.0.0"; then
        sed -i '/listen:/a \    host: 0.0.0.0' "${TARGET_DIR}/app-config.yaml"
    fi

    # Add Public IP to CORS origins
    if grep -q "origin:" "${TARGET_DIR}/app-config.yaml"; then
        if ! grep -q "http://${PUBLIC_IP}:7000" "${TARGET_DIR}/app-config.yaml"; then
            sed -i "s|origin:|origin: ['http://${PUBLIC_IP}:7000', |g" "${TARGET_DIR}/app-config.yaml"
        fi
    fi
fi

# 7. Configure Systemd Service for Backstage
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
Environment=NODE_OPTIONS=--max-old-space-size=4096
Environment=PATH=${NODE_BIN_DIR}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

# 8. Enable and Start Backstage Service
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
