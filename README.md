# DevOps Tools Installation Scripts

Automated shell scripts for installing DevOps and monitoring tools on **Amazon Linux 2023**.

## Included Scripts

| Tool | Script | Default Port |
| :--- | :--- | :--- |
| **Prometheus** | `install_prometheus.sh` | `9090` |
| **Grafana** | `install_grafana.sh` | `3000` |

---

## Quick Start Guide

### 1. Prometheus Installation

```bash
chmod +x install_prometheus.sh
./install_prometheus.sh
```

- Access Prometheus UI: `http://<YOUR_EC2_PUBLIC_IP>:9090`

### 2. Grafana Installation

```bash
chmod +x install_grafana.sh
./install_grafana.sh
```

- Access Grafana UI: `http://<YOUR_EC2_PUBLIC_IP>:3000`
- **Default Credentials:** Username: `admin` | Password: `admin`
