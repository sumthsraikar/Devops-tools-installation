#!/bin/bash
# ==============================================================================
# Complete DevOps Monitoring Stack Installer for Amazon Linux 2023
# Installs: Prometheus, Node Exporter, Grafana
# Auto-configures: Prometheus Scraping + Grafana Data Source
# Auto-imports Dashboards: 1860 (Node Exporter), 14282 (Docker), 315 (K8s), 3662 (Prometheus)
# ==============================================================================

set -e

PROMETHEUS_VERSION="2.53.0"
NODE_EXPORTER_VERSION="1.8.1"

echo "=========================================================================="
echo " Starting Full DevOps Monitoring Stack Installation on Amazon Linux 2023"
echo "=========================================================================="

# ------------------------------------------------------------------------------
# 1. Detect System Architecture
# ------------------------------------------------------------------------------
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    SYS_ARCH="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    SYS_ARCH="arm64"
else
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
fi
echo "--> System Architecture detected: $ARCH ($SYS_ARCH)"

# ------------------------------------------------------------------------------
# 2. Install Prometheus
# ------------------------------------------------------------------------------
echo "--> [1/5] Installing Prometheus v${PROMETHEUS_VERSION}..."
if ! id "prometheus" &>/dev/null; then
    sudo useradd --no-create-home --shell /bin/false prometheus
fi

sudo mkdir -p /etc/prometheus /var/lib/prometheus

cd /tmp
PROM_TAR="prometheus-${PROMETHEUS_VERSION}.linux-${SYS_ARCH}.tar.gz"
wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${PROM_TAR}"
tar -xzf "${PROM_TAR}"
PROM_DIR="prometheus-${PROMETHEUS_VERSION}.linux-${SYS_ARCH}"

sudo cp "${PROM_DIR}/prometheus" "${PROM_DIR}/promtool" /usr/local/bin/
sudo cp -r "${PROM_DIR}/consoles" "${PROM_DIR}/console_libraries" /etc/prometheus/

# Create prometheus.yml configured with Prometheus + Node Exporter jobs
cat << 'EOF' | sudo tee /etc/prometheus/prometheus.yml > /dev/null
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

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

rm -rf "${PROM_TAR}" "${PROM_DIR}"
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus

# ------------------------------------------------------------------------------
# 3. Install Node Exporter
# ------------------------------------------------------------------------------
echo "--> [2/5] Installing Node Exporter v${NODE_EXPORTER_VERSION}..."
if ! id "node_exporter" &>/dev/null; then
    sudo useradd --no-create-home --shell /bin/false node_exporter
fi

NODE_TAR="node_exporter-${NODE_EXPORTER_VERSION}.linux-${SYS_ARCH}.tar.gz"
wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_TAR}"
tar -xzf "${NODE_TAR}"
NODE_DIR="node_exporter-${NODE_EXPORTER_VERSION}.linux-${SYS_ARCH}"

sudo cp "${NODE_DIR}/node_exporter" /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf "${NODE_TAR}" "${NODE_DIR}"

cat << 'EOF' | sudo tee /etc/systemd/system/node_exporter.service > /dev/null
[Unit]
Description=Node Exporter Metrics Collector
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# ------------------------------------------------------------------------------
# 4. Install Grafana
# ------------------------------------------------------------------------------
echo "--> [3/5] Installing Grafana..."
cat << 'EOF' | sudo tee /etc/yum.repos.d/grafana.repo > /dev/null
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

sudo dnf check-update || true
sudo dnf install -y grafana jq

# ------------------------------------------------------------------------------
# 5. Auto-Provision Prometheus Data Source in Grafana
# ------------------------------------------------------------------------------
echo "--> [4/5] Auto-configuring Prometheus Data Source in Grafana..."
sudo mkdir -p /etc/grafana/provisioning/datasources/

cat << 'EOF' | sudo tee /etc/grafana/provisioning/datasources/prometheus.yaml > /dev/null
apiVersion: 1

datasources:
  - name: prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
EOF

# ------------------------------------------------------------------------------
# 6. Auto-Import Grafana Dashboards (1860, 14282, 315, 3662)
# ------------------------------------------------------------------------------
echo "--> [5/5] Auto-provisioning Dashboards: 1860, 14282, 315, 3662..."
sudo mkdir -p /etc/grafana/provisioning/dashboards/
sudo mkdir -p /var/lib/grafana/dashboards/

cat << 'EOF' | sudo tee /etc/grafana/provisioning/dashboards/dashboards.yaml > /dev/null
apiVersion: 1

providers:
  - name: 'DevOps Dashboards'
    orgId: 1
    folder: 'DevOps'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Function to download and prepare dashboard JSON
download_dashboard() {
    local DASH_ID=$1
    local DASH_NAME=$2
    echo "    - Downloading Dashboard ${DASH_ID} (${DASH_NAME})..."
    
    local TARGET_FILE="/var/lib/grafana/dashboards/dashboard_${DASH_ID}.json"
    
    curl -s "https://grafana.com/api/dashboards/${DASH_ID}/revisions/latest/download" -o /tmp/dash.json
    
    # Auto-bind Prometheus data source name
    sed -i 's/${DS_PROMETHEUS}/prometheus/g' /tmp/dash.json
    sed -i 's/DS_PROMETHEUS/prometheus/g' /tmp/dash.json
    
    sudo mv /tmp/dash.json "${TARGET_FILE}"
    sudo chown grafana:grafana "${TARGET_FILE}"
}

download_dashboard "1860" "Node Exporter Full"
download_dashboard "14282" "Docker Monitoring cAdvisor"
download_dashboard "315" "Kubernetes Cluster Monitoring"
download_dashboard "3662" "Prometheus 2.0 Overview"

sudo chown -R grafana:grafana /var/lib/grafana/dashboards/

# ------------------------------------------------------------------------------
# 7. Start & Enable Grafana
# ------------------------------------------------------------------------------
echo "--> Starting Grafana Service..."
sudo systemctl daemon-reload
sudo systemctl enable --now grafana-server
sudo systemctl restart prometheus

PUBLIC_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost')

echo ""
echo "=========================================================================="
echo " 🎉 FULL DEVOPS MONITORING STACK INSTALLED SUCCESSFULLY! "
echo "=========================================================================="
echo " Services Status:"
echo "   - Prometheus:     $(systemctl is-active prometheus)"
echo "   - Node Exporter:  $(systemctl is-active node_exporter)"
echo "   - Grafana:        $(systemctl is-active grafana-server)"
echo "--------------------------------------------------------------------------"
echo " Access Links:"
echo "   - Prometheus Web UI: http://${PUBLIC_IP}:9090"
echo "   - Node Exporter:    http://${PUBLIC_IP}:9100/metrics"
echo "   - Grafana Web UI:   http://${PUBLIC_IP}:3000"
echo ""
echo " Grafana Credentials:"
echo "   - Username: admin"
echo "   - Password: admin"
echo ""
echo " Pre-loaded Dashboards inside Grafana (in 'DevOps' folder):"
echo "   1. Node Exporter Full (ID: 1860)"
echo "   2. Docker Monitoring (ID: 14282)"
echo "   3. K8s Cluster Monitoring (ID: 315)"
echo "   4. Prometheus 2.0 Overview (ID: 3662)"
echo "=========================================================================="
