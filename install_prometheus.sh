#!/bin/bash
# ==============================================================================
# Prometheus Automated Installation Script for Amazon Linux 2023
# ==============================================================================

set -e

PROMETHEUS_VERSION="2.53.0"

echo "=== Starting Prometheus Installation on Amazon Linux 2023 ==="

# 1. Detect System Architecture (x86_64 vs Graviton/ARM64)
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    PROM_ARCH="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    PROM_ARCH="arm64"
else
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
fi

echo "--> Detected System Architecture: $ARCH ($PROM_ARCH)"

# 2. Create Prometheus System User & Directories
echo "--> Creating prometheus user and data directories..."
if ! id "prometheus" &>/dev/null; then
    sudo useradd --no-create-home --shell /bin/false prometheus
fi

sudo mkdir -p /etc/prometheus /var/lib/prometheus

# 3. Download & Extract Prometheus
echo "--> Downloading Prometheus v${PROMETHEUS_VERSION}..."
cd /tmp
TAR_FILE="prometheus-${PROMETHEUS_VERSION}.linux-${PROM_ARCH}.tar.gz"
wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${TAR_FILE}"

echo "--> Extracting Prometheus..."
tar -xzf "${TAR_FILE}"
EXTRACTED_DIR="prometheus-${PROMETHEUS_VERSION}.linux-${PROM_ARCH}"
cd "${EXTRACTED_DIR}"

# 4. Copy Binaries & Setup Permissions
echo "--> Setting up binaries and configurations..."
sudo cp prometheus promtool /usr/local/bin/
sudo cp -r consoles console_libraries /etc/prometheus/

if [ ! -f /etc/prometheus/prometheus.yml ]; then
    sudo cp prometheus.yml /etc/prometheus/prometheus.yml
fi

sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

# Cleanup temporary download files
cd /tmp
rm -rf "${TAR_FILE}" "${EXTRACTED_DIR}"

# 5. Create Systemd Service File
echo "--> Creating systemd service file..."
cat << 'EOF' | sudo tee /etc/systemd/system/prometheus.service > /dev/null
[Unit]
Description=Prometheus Monitoring Server
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 6. Reload Systemd, Enable & Start Prometheus
echo "--> Enabling and starting Prometheus service..."
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus

echo ""
echo "=========================================================================="
echo " Prometheus Installation Complete!"
echo " Service Status:"
sudo systemctl status prometheus --no-pager
echo " Access Prometheus Web UI at: http://$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost'):9090"
echo "=========================================================================="
