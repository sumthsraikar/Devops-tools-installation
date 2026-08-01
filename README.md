# DevOps Tools Installation Scripts

Automated shell scripts for installing DevOps tools on **Amazon Linux 2023**.

## Included Scripts

| Tool / Script | File | Description & Ports |
| :--- | :--- | :--- |
| **☸️ Kubernetes Tools** | `install_kubernetes.sh` | Installs **kubectl**, **Minikube** (local cluster engine), and **Helm 3** package manager. |
| **🐳 Docker & Docker Compose** | `install_docker.sh` | Installs **Docker Engine** & **Docker Compose v2** in a single script. Enables systemd service & user group permissions. |
| **⚡ Grafana & Full Monitoring Stack** | `install_grafana.sh` | **Full Stack Installer!** Installs Grafana (`3000`), Prometheus (`9090`), Node Exporter (`9100`), auto-links Prometheus data source, and auto-imports dashboards **1860**, **14282**, **315**, **3662**. |
| **Prometheus (Standalone)** | `install_prometheus.sh` | Standalone Prometheus Server (`9090`). |

---

## Quick Start Guide

### 1. Install Kubernetes Tools (kubectl, Minikube, Helm 3)
```bash
chmod +x install_kubernetes.sh
./install_kubernetes.sh

# Start single-node K8s cluster
minikube start --driver=docker
```

### 2. Install Docker & Docker Compose
```bash
chmod +x install_docker.sh
./install_docker.sh
```

### 3. Install Grafana & Full Monitoring Stack
```bash
chmod +x install_grafana.sh
./install_grafana.sh
```
