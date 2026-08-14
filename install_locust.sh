#!/bin/bash
# ==============================================================================
# Locust Load Testing Tool Automated Installation Script for Amazon Linux 2023
# Installs Python 3, Pip, Locust Load Tester (Web UI Port: 8089)
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Locust Load Testing Tool Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Update DNF package manager & install Python 3 prerequisites
echo "--> Updating DNF package manager and installing Python 3 dependencies..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip python3-devel gcc libffi-devel

# 2. Create virtual environment for Locust to prevent RPM setuptools package conflicts
echo "--> Creating Python virtual environment at /opt/locust-venv..."
sudo python3 -m venv /opt/locust-venv

# 3. Upgrade pip & install Locust inside the virtual environment
echo "--> Upgrading pip and installing Locust inside virtual environment..."
sudo /opt/locust-venv/bin/pip install --upgrade pip setuptools wheel
sudo /opt/locust-venv/bin/pip install --upgrade locust

# 4. Create global symlinks for locust executable
echo "--> Linking 'locust' command to system PATH (/usr/local/bin and /usr/bin)..."
sudo ln -sf /opt/locust-venv/bin/locust /usr/local/bin/locust
sudo ln -sf /opt/locust-venv/bin/locust /usr/bin/locust 2>/dev/null || true

# 5. Verify Locust installation
echo "--> Verifying Locust installation..."
LOCUST_VERSION=$(locust --version 2>/dev/null || /opt/locust-venv/bin/locust --version)

# 6. Create a sample locustfile.py for quick testing if not present
SAMPLE_LOCUSTFILE="locustfile.py"
if [ ! -f "$SAMPLE_LOCUSTFILE" ]; then
    echo "--> Creating sample '$SAMPLE_LOCUSTFILE' in current directory..."
    cat << 'EOF' > locustfile.py
from locust import HttpUser, task, between

class QuickstartUser(HttpUser):
    wait_time = between(1, 2.5)

    @task
    def hello_world(self):
        self.client.get("/")

    @task(3)
    def view_items(self):
        self.client.get("/health")
EOF
fi

# Detect Public or Private IP address
EC2_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')
if [ -z "$EC2_IP" ]; then
    EC2_IP="localhost"
fi

echo ""
echo "=========================================================================="
echo " 🎉 Locust Installed Successfully!"
echo "=========================================================================="
echo " Installed Version:"
echo "   $LOCUST_VERSION"
echo "--------------------------------------------------------------------------"
echo " Web UI Access (When running with Web Interface):"
echo "   - Web UI URL:   http://${EC2_IP}:8089"
echo "--------------------------------------------------------------------------"
echo " Quick Usage Examples:"
echo "   1. Start Locust Web UI with sample locustfile.py:"
echo "      locust -f locustfile.py --web-host 0.0.0.0 --web-port 8089"
echo ""
echo "   2. Run Headless Load Test (No Web UI):"
echo "      locust -f locustfile.py --headless -u 100 -r 10 --run-time 1m --host http://example.com"
echo ""
echo "   3. Run in Background with nohup:"
echo "      nohup locust -f locustfile.py --web-host 0.0.0.0 --web-port 8089 > locust.log 2>&1 &"
echo "=========================================================================="
