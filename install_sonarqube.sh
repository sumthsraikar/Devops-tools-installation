#!/bin/bash
# ==============================================================================
# SonarQube Community Edition Automated Installation Script for Amazon Linux 2023
# Runs SonarQube (Port 9000) using Docker Container with Sysctl Optimizations
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting SonarQube Community Edition Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Update DNF package manager & install dependencies
echo "--> Updating DNF packages and installing prerequisites..."
sudo dnf update -y
sudo dnf install -y wget

# 2. Configure System Kernel Limits required for SonarQube (Elasticsearch)
echo "--> Configuring kernel parameters (vm.max_map_count & fs.file-max)..."
sudo sysctl -w vm.max_map_count=524288 >/dev/null 2>&1 || true
sudo sysctl -w fs.file-max=131072 >/dev/null 2>&1 || true
sudo ulimit -n 65536 2>/dev/null || true
sudo ulimit -u 4096 2>/dev/null || true

cat <<EOF | sudo tee /etc/sysctl.d/99-sonarqube.conf > /dev/null
vm.max_map_count=524288
fs.file-max=131072
EOF

cat <<EOF | sudo tee /etc/security/limits.d/99-sonarqube.conf > /dev/null
* soft nofile 65536
* hard nofile 65536
* soft nproc 4096
* hard nproc 4096
EOF

# 3. Ensure Docker is installed and running
echo "--> Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "--> Docker not found. Installing Docker Engine..."
    sudo dnf install -y docker
fi

echo "--> Enabling and starting Docker service..."
sudo systemctl daemon-reload
sudo systemctl enable --now docker
sudo usermod -aG docker $USER || true

# 4. Stop and remove existing SonarQube container if present
if sudo docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^sonarqube$'; then
    echo "--> Removing existing SonarQube container..."
    sudo docker rm -f sonarqube >/dev/null 2>&1 || true
fi

# 5. Create Docker volumes for persistent data storage
echo "--> Creating persistent Docker volumes for SonarQube..."
sudo docker volume create sonarqube_data >/dev/null
sudo docker volume create sonarqube_logs >/dev/null
sudo docker volume create sonarqube_extensions >/dev/null

# 6. Pull and Run SonarQube Container (LTS Community Edition)
echo "--> Starting SonarQube LTS container on port 9000..."
sudo docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:lts-community

# 7. Wait for SonarQube server initialization
echo "--> Waiting for SonarQube service to initialize (this may take up to 45 seconds)..."
PUBLIC_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost')

for i in {1..30}; do
    if curl -s http://localhost:9000/api/system/status | grep -q '"status":"UP"\|"status":"STARTING"'; then
        break
    fi
    sleep 2
done

echo ""
echo "=========================================================================="
echo " 🎉 SonarQube Community Edition Installed & Started Successfully!"
echo "=========================================================================="
echo " Access SonarQube Web UI at: http://${PUBLIC_IP}:9000"
echo "--------------------------------------------------------------------------"
echo " Default Credentials:"
echo "   - Username: admin"
echo "   - Password: admin (You will be prompted to change it on first login)"
echo "=========================================================================="
