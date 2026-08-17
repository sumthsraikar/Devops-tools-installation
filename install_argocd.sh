#!/bin/bash
# ==============================================================================
# Argo CD (GitOps Continuous Delivery) Automated Installation Script
# Supports: Amazon Linux 2023 / RHEL / Ubuntu / Debian
# Installs: Argo CD Server Manifests, Argo CD CLI, and Service Configuration
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Argo CD GitOps Installation & Configuration"
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
# 2. Check & Install Prerequisites (kubectl & curl)
# ------------------------------------------------------------------------------
echo "--> Checking prerequisites..."

if ! command -v curl &> /dev/null; then
    echo "--> Installing curl..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y curl
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update -y && sudo apt-get install -y curl
    fi
fi

if ! command -v kubectl &> /dev/null; then
    echo "--> kubectl not found. Installing latest stable kubectl..."
    KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt || echo "v1.30.0")
    curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${K8S_ARCH}/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    echo "--> kubectl installed successfully."
fi

# ------------------------------------------------------------------------------
# 3. Verify Kubernetes Cluster Connectivity
# ------------------------------------------------------------------------------
echo "--> Verifying Kubernetes cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    echo "⚠️  Kubernetes cluster is not currently reachable via kubectl."
    if command -v minikube &> /dev/null; then
        echo "--> Detected Minikube. Attempting to start Minikube cluster..."
        sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
        minikube start --driver=docker || true
    else
        echo "⚠️  Please ensure your Kubernetes cluster (Minikube/EKS/K3s/Kind) is running."
        echo "    Run './install_kubernetes.sh' to install Minikube & kubectl if needed."
    fi
fi

# ------------------------------------------------------------------------------
# 4. Install Argo CD Manifests into Kubernetes
# ------------------------------------------------------------------------------
echo "--> Creating 'argocd' namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "--> Applying official Argo CD stable manifests..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ------------------------------------------------------------------------------
# 5. Configure Argo CD Server Service (Patch to NodePort for Easy Access)
# ------------------------------------------------------------------------------
echo "--> Configuring Argo CD server service (setting type to NodePort)..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}' || true

# ------------------------------------------------------------------------------
# 6. Install Argo CD CLI
# ------------------------------------------------------------------------------
echo "--> Downloading latest Argo CD CLI binary for linux-${K8S_ARCH}..."
ARGOCD_VERSION=$(curl -sL https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "v2.12.0")

if [ -z "$ARGOCD_VERSION" ]; then
    ARGOCD_VERSION="v2.12.0"
fi

echo "--> Downloading Argo CD CLI version: ${ARGOCD_VERSION}..."
curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${K8S_ARCH}"
sudo install -m 555 argocd /usr/local/bin/argocd
rm -f argocd

# ------------------------------------------------------------------------------
# 7. Wait for Argo CD Server to Initialize
# ------------------------------------------------------------------------------
echo "--> Waiting for Argo CD Server deployment to be ready (up to 120s)..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=120s 2>/dev/null || true

# ------------------------------------------------------------------------------
# 8. Start Background Port Forwarding (Port 8888)
# ------------------------------------------------------------------------------
echo "--> Starting Argo CD Server port-forwarding on port 8888 in background..."
pkill -f "kubectl port-forward.*8888:443" 2>/dev/null || true
nohup kubectl port-forward svc/argocd-server -n argocd 8888:443 --address 0.0.0.0 > /tmp/argocd-port-forward.log 2>&1 &
sleep 2

# ------------------------------------------------------------------------------
# 9. Retrieve Public/Host IP, NodePort & Initial Admin Password
# ------------------------------------------------------------------------------
PUBLIC_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
NODE_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null || echo "30080")

echo "--> Retrieving Argo CD initial admin password..."
ADMIN_PASS=""
for i in {1..15}; do
    ADMIN_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode 2>/dev/null || true)
    if [ -n "$ADMIN_PASS" ]; then
        break
    fi
    sleep 2
done

if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS="Run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
fi

# ------------------------------------------------------------------------------
# 10. Completion Summary & Quick Start
# ------------------------------------------------------------------------------
echo ""
echo "=========================================================================="
echo " 🎉 Argo CD Installed Successfully!"
echo "=========================================================================="
echo " Installed Versions:"
echo "   - Argo CD CLI:    $(argocd version --client --short 2>/dev/null || echo ${ARGOCD_VERSION})"
echo "   - Target Server:  Argo CD Core/Server (${ARGOCD_VERSION})"
echo "--------------------------------------------------------------------------"
echo " Argo CD Web UI Access:"
echo "   - Web UI URL:       https://${PUBLIC_IP}:8888 (Port-forwarded)"
echo "   - Localhost URL:    https://localhost:8888"
echo "   - NodePort URL:     https://${PUBLIC_IP}:${NODE_PORT}"
echo "--------------------------------------------------------------------------"
echo " Port Forward Command (running in background, log: /tmp/argocd-port-forward.log):"
echo "   kubectl port-forward svc/argocd-server -n argocd 8888:443 --address 0.0.0.0"
echo "--------------------------------------------------------------------------"
echo " Initial Login Credentials:"
echo "   - Username: admin"
echo "   - Password: ${ADMIN_PASS}"
echo "--------------------------------------------------------------------------"
echo " Quick Start CLI Commands:"
echo "   - Login via CLI:    argocd login localhost:8888 --username admin --insecure"
echo "   - Change Password:  argocd account update-password"
echo "   - List Apps:        argocd app list"
echo "=========================================================================="
