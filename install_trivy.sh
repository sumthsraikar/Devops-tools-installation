#!/bin/bash
# ==============================================================================
# Trivy Vulnerability Scanner Automated Installation Script for Amazon Linux 2023
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Trivy Vulnerability Scanner Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Update DNF package manager & install dependencies
echo "--> Updating DNF packages and installing prerequisites..."
sudo dnf update -y
sudo dnf install -y wget curl

# 2. Add Official Trivy RPM Repository & Import GPG Key
echo "--> Setting up Trivy official repository..."
sudo rpm --import https://aquasecurity.github.io/trivy-repo/rpm/public.key

cat <<EOF | sudo tee /etc/yum.repos.d/trivy.repo > /dev/null
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key
EOF

# 3. Install Trivy
echo "--> Installing Trivy package..."
if sudo dnf install -y trivy 2>/dev/null; then
    echo "--> Trivy package installed successfully via DNF repository."
else
    echo "--> DNF package installation failed or unavailable. Falling back to official install script..."
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
fi

# 4. Verify Installation
echo ""
echo "=========================================================================="
echo " 🎉 Trivy Installed Successfully!"
echo "=========================================================================="
echo " Installed Version:"
echo "   $(trivy --version | head -n 1)"
echo "--------------------------------------------------------------------------"
echo " Quick Usage Examples:"
echo "   - Scan a container image:    trivy image <image-name>"
echo "   - Scan current repository:   trivy fs ."
echo "=========================================================================="
