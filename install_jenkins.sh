#!/bin/bash
# ==============================================================================
# Jenkins Automated Installation Script for Amazon Linux 2023
# Installs: Java 17 (Amazon Corretto), Fontconfig & Jenkins LTS
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Jenkins Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Update DNF & Install Java 17 and Fontconfig (Required by Jenkins)
echo "--> [1/4] Installing Java 17 (Amazon Corretto) and fontconfig..."
sudo dnf update -y
sudo dnf install -y java-17-amazon-corretto fontconfig wget

# Ensure Java 17 is default
sudo alternatives --set java /usr/lib/jvm/java-17-amazon-corretto/bin/java 2>/dev/null || true

echo "--> Verified Java Version:"
java -version

# 2. Add Jenkins Official RedHat/YUM Repository & Key
echo "--> [2/4] Adding Jenkins YUM repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# 3. Install Jenkins via DNF
echo "--> [3/4] Installing Jenkins..."
sudo dnf check-update || true
sudo dnf install -y jenkins

# 4. Enable and Start Jenkins Service
echo "--> [4/4] Enabling and starting Jenkins service..."
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl restart jenkins

PUBLIC_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost')

# Brief wait to ensure initialAdminPassword file is generated
sleep 5

INITIAL_PASS=""
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    INITIAL_PASS=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
fi

echo ""
echo "=========================================================================="
echo " 🎉 Jenkins Installed & Started Successfully!"
echo "=========================================================================="
echo " Service Status:"
sudo systemctl status jenkins --no-pager
echo "--------------------------------------------------------------------------"
echo " Access Links:"
echo "   - Jenkins Web UI: http://${PUBLIC_IP}:8080"
echo "--------------------------------------------------------------------------"
if [ -n "$INITIAL_PASS" ]; then
    echo " 🔑 Initial Admin Password:"
    echo "   ${INITIAL_PASS}"
else
    echo " 🔑 Initial Admin Password location:"
    echo "   sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi
echo "=========================================================================="
