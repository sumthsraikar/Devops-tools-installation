# DevOps Tools Installation Scripts

Automated shell scripts for installing DevOps tools on **Amazon Linux 2023**.

## Included Scripts

| Tool / Script | File | Description & Ports |
| :--- | :--- | :--- |
| ** Jenkins (Stable LTS)** | `install_jenkins.sh` | Installs **Jenkins LTS Stable** & **Java 21 (Amazon Corretto)**. Enables systemd service (`8080`) & displays initial admin password. |
| ** Kubernetes Tools** | `install_kubernetes.sh` | Installs **kubectl**, **Minikube** (local cluster engine), and **Helm 3** package manager. |
| ** Docker & Docker Compose** | `install_docker.sh` | Installs **Docker Engine** & **Docker Compose v2** in a single script. Enables systemd service & user group permissions. |
# DevOps Tools Installation Scripts

Automated shell scripts for installing DevOps tools on **Amazon Linux 2023**.

## Included Scripts

| Tool / Script | File | Description & Ports |
| :--- | :--- | :--- |
| ** Jenkins (Stable LTS)** | `install_jenkins.sh` | Installs **Jenkins LTS Stable** & **Java 21 (Amazon Corretto)**. Enables systemd service (`8080`) & displays initial admin password. |
| ** Kubernetes Tools** | `install_kubernetes.sh` | Installs **kubectl**, **Minikube** (local cluster engine), and **Helm 3** package manager. |
| ** Docker & Docker Compose** | `install_docker.sh` | Installs **Docker Engine** & **Docker Compose v2** in a single script. Enables systemd service & user group permissions. |
| ** Grafana & Full Monitoring Stack** | `install_grafana.sh` | **Full Stack Master Script!** Installs Grafana (`3000`), Prometheus (`9090`), Node Exporter (`9100`), auto-links Prometheus data source, and auto-imports dashboards **1860**, **14282**, **315**, **3662**. |
| **Prometheus (Standalone)** | `install_prometheus.sh` | Standalone Prometheus Server (`9090`). |
| **🛡️ Trivy Vulnerability Scanner** | `install_trivy.sh` | Installs **Trivy** vulnerability scanner for container images, file systems, and Git repositories. |
| **🔍 SonarQube Community Edition** | `install_sonarqube.sh` | Installs & runs **SonarQube LTS Community** (`9000`) in Docker with kernel limit optimizations. |
| **🎧 Spotify Backstage** | `install_backstage.sh` | Installs **Spotify Backstage** Developer Portal (`7000`/`7007`), Node.js 20, Yarn, Docker, auto-configures `app-config.yaml`, and configures systemd service. |
| **🤠 Rancher Server** | `install_rancher.sh` | Installs & runs **Rancher Management Server** (`4444`/`8081`) in Docker container with IP forwarding configuration. |
| **🐳 Portainer CE** | `install_portainer.sh` | Installs & runs **Portainer CE Container Management** (`9443`/`9000`) in Docker with persistent volume storage. |
| **🦗 Locust Load Testing** | `install_locust.sh` | Installs **Locust** load testing tool (`8089`), Python 3, pip, and creates a sample `locustfile.py`. |
| **📊 Netdata Real-Time Monitoring** | `install_netdata.sh` | Installs **Netdata** real-time performance & health monitoring agent (`19999`) and enables systemd service. |

---

## Quick Start Guide

### 1. Install Jenkins LTS (Stable)
```bash
chmod +x install_jenkins.sh
./install_jenkins.sh
```

### 2. Install Kubernetes Tools (kubectl, Minikube, Helm 3)
```bash
chmod +x install_kubernetes.sh
./install_kubernetes.sh
```

### 3. Install Docker & Docker Compose
```bash
chmod +x install_docker.sh
./install_docker.sh
```

### 4. Install Grafana & Full Monitoring Stack
```bash
chmod +x install_grafana.sh
./install_grafana.sh
```

### 5. Install Trivy Vulnerability Scanner
```bash
chmod +x install_trivy.sh
./install_trivy.sh
```

### 6. Install SonarQube Community Edition
```bash
chmod +x install_sonarqube.sh
./install_sonarqube.sh
```

### 7. Install Spotify Backstage Developer Portal
```bash
chmod +x install_backstage.sh
./install_backstage.sh
```

### 8. Install Rancher Management Server
```bash
chmod +x install_rancher.sh
./install_rancher.sh
```

### 9. Install Portainer CE Management
```bash
chmod +x install_portainer.sh
./install_portainer.sh
```

### 10. Install Locust Load Testing Tool
```bash
chmod +x install_locust.sh
./install_locust.sh
```

### 11. Install Netdata Real-Time Monitoring Agent
```bash
chmod +x install_netdata.sh
./install_netdata.sh
```
