#!/bin/bash
# ==============================================================================
# Portainer CE Automated Installation Script for Amazon Linux 2023
# Runs Portainer Server (Port 9443 HTTPS / 9000 HTTP) using Docker Container
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Portainer CE Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Check and Install Docker Engine if not present
echo "--> Checking Docker installation..."
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
        sudo systemctl daemon-reload
        sudo systemctl enable --now docker
    fi
fi

# 2. Create persistent Docker volume for Portainer data
echo "--> Creating persistent Docker volume 'portainer_data'..."
sudo docker volume create portainer_data >/dev/null 2>&1 || true

# 3. Stop and remove existing Portainer container if present
if sudo docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^portainer$'; then
    echo "--> Removing existing Portainer container..."
    sudo docker rm -f portainer >/dev/null 2>&1 || true
fi

# 4. Pull and Run Portainer Server Container (Portainer CE Latest)
echo "--> Pulling and starting Portainer CE container..."
sudo docker run -d \
  --name portainer \
  --restart=always \
  -p 9000:9000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# 5. Wait for Portainer container initialization
echo "--> Waiting for Portainer service to initialize..."
sleep 5

# Detect Public or Private IP address
EC2_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')
if [ -z "$EC2_IP" ]; then
    EC2_IP="localhost"
fi

echo ""
echo "=========================================================================="
echo " 🎉 Portainer CE Installed & Started Successfully!"
echo "=========================================================================="
echo " Container Status:"
sudo docker ps --filter "name=portainer" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
echo "--------------------------------------------------------------------------"
echo " Access URLs:"
echo "   - HTTPS Web UI: https://${EC2_IP}:9443"
echo "   - HTTP Web UI:  http://${EC2_IP}:9000"
echo "--------------------------------------------------------------------------"
echo " 🔑 Initial Admin Setup Note:"
echo "   - Open the web interface in your browser within 5 minutes of setup"
echo "     to set up the administrator account."
echo ""
echo " Useful Commands:"
echo "   - Check Logs:   sudo docker logs portainer"
echo "   - Stop Server:  sudo docker stop portainer"
echo "   - Start Server: sudo docker start portainer"
echo "=========================================================================="
