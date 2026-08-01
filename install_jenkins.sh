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

# 2. Install Java 17 LTS (Amazon Corretto - Official Jenkins Dependency)
echo "--> Installing Java 17 (Amazon Corretto)..."
sudo dnf install -y java-17-amazon-corretto wget

# Verify Java Installation
echo "--> Java Version:"
java -version

# 3. Add Official Jenkins LTS (Stable) Repository & Import GPG Key
echo "--> Adding Jenkins LTS Stable repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# 4. Install Jenkins
echo "--> Installing Jenkins LTS..."
sudo dnf check-update || true
sudo dnf install -y jenkins

# 5. Enable and Start Jenkins Service
echo "--> Enabling and starting Jenkins service..."
sudo systemctl daemon-reload
sudo systemctl enable --now jenkins

# 6. Retrieve Public IP & Initial Admin Password
PUBLIC_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo 'localhost')

# Allow 3 seconds for initial password generation
sleep 3
ADMIN_PASS=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Run 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'")

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
