#!/bin/bash
# ==============================================================================
# Jenkins Stable (LTS) Automated Installation Script for Amazon Linux 2023
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Jenkins LTS (Stable) Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Update DNF package manager
echo "--> Updating DNF packages..."
sudo dnf update -y

# 2. Install Java 17 LTS (Amazon Corretto), Fontconfig & Wget
# Note: fontconfig is a REQUIRED dependency for Jenkins UI graphics engine on AL2023
echo "--> Installing Java 17 (Amazon Corretto), fontconfig, and wget..."
sudo dnf install -y java-17-amazon-corretto fontconfig wget

# Remove any existing broken symlink at /usr/bin/java to avoid circular symlinks
sudo rm -f /usr/bin/java /usr/local/bin/java

# Explicitly link Amazon Corretto 17 Java binary to /usr/bin/java
CORRETTO_JAVA="/usr/lib/jvm/java-17-amazon-corretto/bin/java"
if [ -f "$CORRETTO_JAVA" ]; then
    sudo ln -sf "$CORRETTO_JAVA" /usr/bin/java
    sudo ln -sf "$CORRETTO_JAVA" /usr/local/bin/java
fi

export PATH="/usr/lib/jvm/java-17-amazon-corretto/bin:$PATH"

echo "--> Verified Java Version:"
java -version || /usr/bin/java -version

# 3. Add Official Jenkins LTS (Stable) Repository & Import GPG Key
echo "--> Adding Jenkins LTS Stable repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# 4. Install Jenkins
echo "--> Installing Jenkins LTS..."
sudo dnf check-update || true
sudo dnf install -y jenkins

# 5. Configure Systemd Override & Directory Permissions
echo "--> Configuring Systemd override & directory permissions..."
sudo mkdir -p /etc/systemd/system/jenkins.service.d/

cat << 'EOF' | sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null
[Service]
Environment="JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto"
Environment="JENKINS_JAVA_CMD=/usr/lib/jvm/java-17-amazon-corretto/bin/java"
EOF

sudo mkdir -p /var/lib/jenkins /var/log/jenkins /var/cache/jenkins
sudo chown -R jenkins:jenkins /var/lib/jenkins /var/log/jenkins /var/cache/jenkins

# 6. Enable and Start Jenkins Service
echo "--> Enabling and starting Jenkins service..."
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl restart jenkins

# 7. Retrieve Public IP & Initial Admin Password
PUBLIC_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost')

echo "--> Waiting for Jenkins to initialize and generate initial admin password..."
ADMIN_PASS=""
for i in {1..20}; do
    if sudo test -f /var/lib/jenkins/secrets/initialAdminPassword; then
        ADMIN_PASS=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
        break
    fi
    sleep 1
done

if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS="Run 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
fi

echo ""
echo "=========================================================================="
echo " 🎉 Jenkins LTS (Stable) Installed Successfully!"
echo "=========================================================================="
echo " Service Status:"
sudo systemctl status jenkins --no-pager
echo "--------------------------------------------------------------------------"
echo " Access Jenkins Web UI at: http://${PUBLIC_IP}:8080"
echo "--------------------------------------------------------------------------"
echo " Initial Admin Password:"
echo " ${ADMIN_PASS}"
echo "=========================================================================="
