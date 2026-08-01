#!/bin/bash
# ==============================================================================
# Docker & Docker Compose Automated Installation Script for Amazon Linux 2023
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Docker & Docker Compose Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Update DNF package manager
echo "--> Updating DNF packages..."
sudo dnf update -y

# 2. Install Docker Engine
echo "--> Installing Docker Engine..."
sudo dnf install -y docker

# 3. Enable and Start Docker Service
echo "--> Enabling and starting Docker service..."
sudo systemctl daemon-reload
sudo systemctl enable --now docker

# 4. Add current user to docker group (run docker without sudo)
echo "--> Adding user (${USER}) to docker group..."
sudo usermod -aG docker $USER || true

# 5. Detect System Architecture (x86_64 vs Graviton/ARM64)
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    DOCKER_ARCH="x86_64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    DOCKER_ARCH="aarch64"
else
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
fi

echo "--> System Architecture detected: $ARCH ($DOCKER_ARCH)"

# 6. Download & Install Docker Compose v2 Latest Release
echo "--> Installing Docker Compose (v2 Latest)..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K[^"]+' || echo "v2.28.1")

echo "--> Downloading Docker Compose ${COMPOSE_VERSION}..."
sudo curl -sL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${DOCKER_ARCH}" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Also enable 'docker compose' CLI plugin command
sudo mkdir -p /usr/libexec/docker/cli-plugins
sudo cp -f /usr/local/bin/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose

echo ""
echo "=========================================================================="
echo " 🎉 Docker & Docker Compose Installed Successfully!"
echo "=========================================================================="
echo " Service Status:"
sudo systemctl status docker --no-pager
echo "--------------------------------------------------------------------------"
echo " Installed Versions:"
echo "   - Docker Engine:  $(docker --version)"
echo "   - Docker Compose: $(docker-compose --version)"
echo "--------------------------------------------------------------------------"
echo " ⚠️ Note: Run 'newgrp docker' (or log out & in) to use docker without sudo."
echo "=========================================================================="
