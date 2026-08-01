#!/bin/bash
# ==============================================================================
# Jenkins Automated Installation Script for Amazon Linux 2023
# Installs: Java 17 (Amazon Corretto), Fontconfig & Jenkins LTS
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Jenkins Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Update DNF & Install Java 17, Java Devel & Fontconfig
echo "--> [1/5] Installing Java 17 (Amazon Corretto Devel) and fontconfig..."
sudo dnf update -y
sudo dnf install -y java-17-amazon-corretto java-17-amazon-corretto-devel fontconfig wget

# Link Java binary into /usr/bin/java & /usr/local/bin/java
CORRETTO_JAVA="/usr/lib/jvm/java-17-amazon-corretto/bin/java"
if [ -f "$CORRETTO_JAVA" ]; then
    sudo ln -sf "$CORRETTO_JAVA" /usr/bin/java
    sudo ln -sf "$CORRETTO_JAVA" /usr/local/bin/java
fi

export PATH="/usr/lib/jvm/java-17-amazon-corretto/bin:$PATH"

echo "--> Verified Java Version:"
java -version || /usr/bin/java -version

# 2. Add Jenkins Official RedHat/YUM Repository & Key
echo "--> [2/5] Adding Jenkins YUM repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# 3. Install Jenkins via DNF
echo "--> [3/5] Installing Jenkins package..."
sudo dnf check-update || true
sudo dnf install -y jenkins

# 4. Configure Systemd Override for Java Path & Environment
echo "--> [4/5] Configuring systemd override for Jenkins Java environment..."
sudo mkdir -p /etc/systemd/system/jenkins.service.d/

cat << 'EOF' | sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null
[Service]
Environment="JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto"
Environment="JENKINS_JAVA_CMD=/usr/lib/jvm/java-17-amazon-corretto/bin/java"
EOF

# Ensure proper directory permissions
sudo mkdir -p /var/lib/jenkins /var/log/jenkins /var/cache/jenkins
sudo chown -R jenkins:jenkins /var/lib/jenkins /var/log/jenkins /var/cache/jenkins

# 5. Enable and Start Jenkins Service
echo "--> [5/5] Reloading systemd and starting Jenkins service..."
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
