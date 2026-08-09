#!/bin/bash
# ==============================================================================
# Rancher Server Automated Installation Script for Amazon Linux 2023
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Rancher Server Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Update DNF package manager & install prerequisites
echo "--> Updating DNF packages..."
sudo dnf update -y
sudo dnf install -y --allowerasing ca-certificates iptables

# 2. Check and Install Docker Engine if not present
if ! command -v docker &> /dev/null; then
    echo "--> Docker not found. Installing Docker Engine..."
    sudo dnf install -y docker
    sudo systemctl daemon-reload
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER || true
else
    echo "--> Docker is already installed."
    if ! systemctl is-active --quiet docker; then
        echo "--> Starting Docker service..."
        sudo systemctl enable --now docker
    fi
fi

# 3. Ensure Kernel Parameters for IP Forwarding
echo "--> Configuring sysctl network settings..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-rancher.conf > /dev/null
sudo sysctl --system > /dev/null 2>&1 || true

# 4. Stop and remove existing rancher container if present
if sudo docker ps -a --format '{{.Names}}' | grep -q "^rancher$"; then
    echo "--> Found existing container named 'rancher'. Recreating..."
    sudo docker stop rancher > /dev/null 2>&1 || true
    sudo docker rm rancher > /dev/null 2>&1 || true
fi

# 5. Pull & Run Rancher Server Container
echo "--> Pulling and starting Rancher Server container (rancher/rancher:latest)..."
sudo docker run -d \
  --name rancher \
  --restart=unless-stopped \
  -p 8081:80 -p 4444:443 \
  --privileged \
  rancher/rancher:latest

# 6. Wait for Rancher to initialize
echo "--> Waiting for Rancher container to start..."
sleep 15

# Detect Public/Private IP
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "=========================================================================="
echo " 🎉 Rancher Server Installed & Started Successfully!"
echo "=========================================================================="
echo " Container Status:"
sudo docker ps --filter "name=rancher" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
echo "--------------------------------------------------------------------------"
echo " Access URL:"
echo "   - HTTPS: https://${EC2_IP}:4444"
echo "   - HTTP:  http://${EC2_IP}:8081"
echo "--------------------------------------------------------------------------"
echo " 🔑 Initial Bootstrap Password:"
echo "   To get your initial login password, run the following command:"
echo "     sudo docker logs rancher 2>&1 | grep \"Bootstrap Password:\""
echo ""
echo "   Or reset/set a password using:"
echo "     sudo docker exec -ti rancher reset-password"
echo "=========================================================================="
