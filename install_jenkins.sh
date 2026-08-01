#!/bin/bash
# ==============================================================================
# Jenkins LTS (Port 8080) + Docker + Git Automated Installer for AL2023
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Jenkins LTS (Port 8080) Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Update DNF package manager
echo "--> Updating DNF packages..."
sudo dnf update -y

# 2. Install Java 21 LTS (Amazon Corretto), Fontconfig, Git, Docker, Wget
echo "--> Installing Java 21, Fontconfig, Git, Docker, and Wget..."
sudo dnf remove -y java-17-amazon-corretto 2>/dev/null || true
sudo dnf install -y java-21-amazon-corretto fontconfig wget git docker

# 3. Dynamically locate Java 21 binary
echo "--> Locating Java 21 binary..."
REAL_JAVA=$(find /usr/lib/jvm -path "*21*" -name java -type f 2>/dev/null | head -n 1)
if [ -z "$REAL_JAVA" ]; then
    REAL_JAVA=$(find /usr/lib/jvm -name java -type f 2>/dev/null | grep "21" | head -n 1)
fi

if [ -z "$REAL_JAVA" ]; then
    REAL_JAVA=$(type -p java || which java || find /usr/lib/jvm -name java -type f 2>/dev/null | head -n 1)
fi

echo "--> Found Java 21 executable at: ${REAL_JAVA}"

# Clean up broken or self-referencing symlinks at /usr/bin/java
sudo rm -f /usr/bin/java /usr/local/bin/java

if [ -n "$REAL_JAVA" ]; then
    sudo alternatives --install /usr/bin/java java "$REAL_JAVA" 20000 2>/dev/null || true
    sudo alternatives --set java "$REAL_JAVA" 2>/dev/null || true
    sudo ln -sf "$REAL_JAVA" /usr/bin/java
    sudo ln -sf "$REAL_JAVA" /usr/local/bin/java
fi

echo "--> Verified Java Version:"
java -version || "$REAL_JAVA" -version

# 4. Enable and Start Docker Service & Add Users to Docker Group
echo "--> Starting Docker service and adding user permissions..."
sudo systemctl daemon-reload
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user || true

# 5. Add Official Jenkins LTS Repository & Import GPG Key
echo "--> Adding Jenkins LTS Stable repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# 6. Install Jenkins
echo "--> Installing Jenkins package..."
sudo dnf check-update || true
sudo dnf install -y jenkins

# Add jenkins user to docker group
sudo usermod -aG docker jenkins || true

# 7. Configure Systemd Override (Port 8080 & Java 21) & Directory Permissions
echo "--> Configuring Systemd override for Port 8080 & directory permissions..."
JAVA_HOME_DIR=$(dirname $(dirname "$REAL_JAVA"))
sudo mkdir -p /etc/systemd/system/jenkins.service.d/

cat << EOF | sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null
[Service]
Environment="JAVA_HOME=${JAVA_HOME_DIR}"
Environment="JENKINS_JAVA_CMD=${REAL_JAVA}"
Environment="JENKINS_PORT=8080"
EOF

sudo mkdir -p /var/lib/jenkins /var/log/jenkins /var/cache/jenkins
sudo chown -R jenkins:jenkins /var/lib/jenkins /var/log/jenkins /var/cache/jenkins

# 8. Enable & Start Jenkins Service
echo "--> Enabling and starting Jenkins service on Port 8080..."
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

# 9. Retrieve Public IP & Initial Admin Password
PUBLIC_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost')

echo "--> Waiting for Jenkins to initialize and generate initial admin password..."
ADMIN_PASS=""
for i in {1..25}; do
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
echo " 🎉 Jenkins LTS (Port 8080) Installed & Started Successfully!"
echo "=========================================================================="
echo " Service Status:"
sudo systemctl status jenkins --no-pager
echo "--------------------------------------------------------------------------"
echo " Access Jenkins Web UI at: http://${PUBLIC_IP}:8080"
echo "--------------------------------------------------------------------------"
echo " Initial Admin Password:"
echo " ${ADMIN_PASS}"
echo "=========================================================================="
