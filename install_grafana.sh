#!/bin/bash
# ==============================================================================
# Grafana Automated Installation Script for Amazon Linux 2023
# ==============================================================================

set -e

echo "=== Starting Grafana Installation on Amazon Linux 2023 ==="

# 1. Add Grafana DNF/YUM Repository
echo "--> Adding Grafana YUM/DNF repository..."
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

# 2. Update DNF package manager & Install Grafana
echo "--> Installing Grafana..."
sudo dnf check-update || true
sudo dnf install -y grafana

# 3. Reload Systemd, Enable & Start Grafana Service
echo "--> Enabling and starting Grafana service..."
sudo systemctl daemon-reload
sudo systemctl enable --now grafana-server

echo ""
echo "=========================================================================="
echo " Grafana Installation Complete!"
echo " Service Status:"
sudo systemctl status grafana-server --no-pager
echo " Access Grafana Web UI at: http://$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost'):3000"
echo " Default Credentials -> Username: admin | Password: admin"
echo "=========================================================================="
