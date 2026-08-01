#!/bin/bash
# ==============================================================================
# Kubernetes Tools Automated Installation Script for Amazon Linux 2023
# Installs: kubectl, Minikube, and Helm 3
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Kubernetes Tools Installation on Amazon Linux 2023"
echo "=========================================================================="

# ------------------------------------------------------------------------------
# 1. Detect System Architecture (x86_64 vs Graviton/ARM64)
# ------------------------------------------------------------------------------
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    K8S_ARCH="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    K8S_ARCH="arm64"
else
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
fi

echo "--> System Architecture detected: $ARCH ($K8S_ARCH)"

# ------------------------------------------------------------------------------
# 2. Fix Docker Socket Permissions for Minikube
# ------------------------------------------------------------------------------
echo "--> Configuring Docker group & socket permissions for Minikube..."
sudo usermod -aG docker $USER || true
sudo chmod 666 /var/run/docker.sock 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. Install kubectl (Kubernetes CLI)
# ------------------------------------------------------------------------------
echo "--> [1/3] Downloading latest stable kubectl..."
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt || echo "v1.30.0")
curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${K8S_ARCH}/kubectl"

echo "--> Installing kubectl to /usr/local/bin/..."
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

# ------------------------------------------------------------------------------
# 4. Install Minikube (Single-Node Kubernetes Cluster Engine)
# ------------------------------------------------------------------------------
echo "--> [2/3] Downloading latest Minikube..."
curl -sLO "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${K8S_ARCH}"

echo "--> Installing minikube to /usr/local/bin/..."
sudo install -o root -g root -m 0755 "minikube-linux-${K8S_ARCH}" /usr/local/bin/minikube
rm -f "minikube-linux-${K8S_ARCH}"

# ------------------------------------------------------------------------------
# 5. Install Helm 3 (Kubernetes Package Manager)
# ------------------------------------------------------------------------------
echo "--> [3/3] Installing Helm 3..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo ""
echo "=========================================================================="
echo " 🎉 Kubernetes Tools Installed Successfully!"
echo "=========================================================================="
echo " Installed Tool Versions:"
echo "   - kubectl:   $(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | head -n1 | awk '{print $2}' || echo 'Installed')"
echo "   - Minikube:  $(minikube version --short 2>/dev/null || minikube version)"
echo "   - Helm 3:    $(helm version --short 2>/dev/null || helm version)"
echo "--------------------------------------------------------------------------"
echo " Quick Start Commands:"
echo "   - Refresh group:           newgrp docker"
echo "   - Start Minikube cluster:  minikube start --driver=docker"
echo "   - Check cluster status:    kubectl cluster-info"
echo "   - View cluster nodes:      kubectl get nodes"
echo "=========================================================================="
