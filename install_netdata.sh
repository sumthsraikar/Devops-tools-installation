#!/bin/bash
# ==============================================================================
# Netdata Real-Time Performance & Health Monitoring Installation Script
# Supported OS: Amazon Linux 2023 / RHEL / CentOS / Ubuntu / Debian
# Default Port: 19999
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Netdata Monitoring Agent Installation"
echo "=========================================================================="

# 1. Update package manager and install prerequisites
echo "--> Installing prerequisites..."
if command -v dnf &> /dev/null; then
    # In Amazon Linux 2023, curl-minimal is pre-installed; avoid conflicting package 'curl'
    sudo dnf install -y --allowerasing wget tar gzip libuuid || sudo dnf install -y wget tar gzip
elif command -v yum &> /dev/null; then
    sudo yum install -y wget tar gzip
elif command -v apt-get &> /dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y curl wget tar gzip
fi

# 2. Download and run the official Netdata Kickstart installer
echo "--> Downloading and executing official Netdata kickstart script..."
# Options:
#   --non-interactive : Run without prompting for manual confirmation
#   --stable-channel  : Install the official stable release
#   --dont-wait       : Do not wait for user input
curl https://get.netdata.cloud/kickstart.sh > /tmp/netdata-kickstart.sh
sudo sh /tmp/netdata-kickstart.sh --non-interactive --stable-channel --dont-wait

# 3. Ensure Netdata systemd service is enabled and started
echo "--> Ensuring Netdata systemd service is active and enabled..."
sudo systemctl daemon-reload
sudo systemctl enable netdata
sudo systemctl restart netdata

# 4. Wait for Netdata service to initialize
echo "--> Waiting for Netdata service to initialize on port 19999..."
sleep 5

# Detect Public or Private IP address
EC2_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')
if [ -z "$EC2_IP" ]; then
    EC2_IP="localhost"
fi

# 5. Output Installation Summary and Access Info
echo ""
echo "=========================================================================="
echo " 🎉 Netdata Monitoring Agent Installed & Started Successfully!"
echo "=========================================================================="
echo " Service Status:"
sudo systemctl is-active --quiet netdata && echo "   Status: Active (Running)" || echo "   Status: Inactive / Failed"
echo "--------------------------------------------------------------------------"
echo " Access URL:"
echo "   - Web Dashboard: http://${EC2_IP}:19999"
echo "--------------------------------------------------------------------------"
echo " ⚙️ Configuration & Paths:"
echo "   - Config Directory:  /etc/netdata"
echo "   - Config Editor:     sudo /etc/netdata/edit-config netdata.conf"
echo "   - Main Log File:     /var/log/netdata/error.log"
echo "--------------------------------------------------------------------------"
echo " Useful Commands:"
echo "   - Check Status:      sudo systemctl status netdata"
echo "   - Restart Service:   sudo systemctl restart netdata"
echo "   - Stop Service:      sudo systemctl stop netdata"
echo "   - Claim to Cloud:    sudo netdata-claim.sh -token=YOUR_TOKEN -rooms=YOUR_ROOM -url=https://app.netdata.cloud"
echo "=========================================================================="
