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
echo "--> Installing Java 17 (Amazon Corretto), fontconfig, and wget..."
sudo dnf install -y java-17-amazon-corretto fontconfig wget

# 3. Dynamically locate Java executable
echo "--> Locating Java binary..."
REAL_JAVA=$(find /usr/lib/jvm -name java -type f 2>/dev/null | grep -E "17|corretto" | head -n 1)
if [ -z "$REAL_JAVA" ]; then
    REAL_JAVA=$(type -p java || which java || find /usr/lib/jvm -name java -type f 2>/dev/null | head -n 1)
fi

echo "--> Found Java executable at: ${REAL_JAVA}"

# Clean up broken or self-referencing symlinks at /usr/bin/java
if [ -L /usr/bin/java ] && ! [ -f /usr/bin/java ]; then
    sudo rm -f /usr/bin/java
fi

if [ -n "$REAL_JAVA" ] && [ "$REAL_JAVA" != "/usr/bin/java" ]; then
    sudo alternatives --install /usr/bin/java java "$REAL_JAVA" 20000 2>/dev/null || true
    sudo alternatives --set java "$REAL_JAVA" 2>/dev/null || true
    sudo ln -sf "$REAL_JAVA" /usr/bin/java 2>/dev/null || true
fi

echo "--> Verified Java Version:"
java -version || "$REAL_JAVA" -version

# 4. Add Official Jenkins LTS (Stable) Repository & Import GPG Key
echo "--> Adding Jenkins LTS Stable repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# 5. Install Jenkins
echo "--> Installing Jenkins LTS..."
sudo dnf check-update || true
sudo dnf install -y jenkins

# 6. Configure Systemd Override & Directory Permissions
echo "--> Configuring Systemd override & directory permissions..."
JAVA_HOME_DIR=$(dirname $(dirname "$REAL_JAVA"))
sudo mkdir -p /etc/systemd/system/jenkins.service.d/

cat << EOF | sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null
[Service]
Environment="JAVA_HOME=${JAVA_HOME_DIR}"
Environment="JENKINS_JAVA_CMD=${REAL_JAVA}"
EOF

sudo mkdir -p /var/lib/jenkins /var/log/jenkins /var/cache/jenkins
sudo chown -R jenkins:jenkins /var/lib/jenkins /var/log/jenkins /var/cache/jenkins

# 7. Enable and Start Jenkins Service
echo "--> Enabling and starting Jenkins service..."
sudo systemctl daemon-reload
sudo systemctl enable jenkins

if ! sudo systemctl restart jenkins; then
    echo ""
    echo "=========================================================================="
    echo " ❌ Jenkins service failed to start. Printing recent log diagnostic:"
    echo "=========================================================================="
    sudo journalctl -u jenkins.service --no-pager -n 40
    exit 1
fi

# 8. Retrieve Public IP & Initial Admin Password
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
