# DevOps Tools Installation Scripts

Automated shell scripts for installing DevOps monitoring tools on **Amazon Linux 2023**.

## Included Scripts

| Tool / Script | File | Description & Ports |
| :--- | :--- | :--- |
| **⚡ Grafana & Full Stack Master Installer** | `install_grafana.sh` | **Full Monitoring Stack!** Installs Grafana (`3000`), Prometheus (`9090`), Node Exporter (`9100`), auto-links Prometheus data source, and auto-imports Grafana dashboards **1860**, **14282**, **315**, and **3662**. |
| **Prometheus (Standalone)** | `install_prometheus.sh` | Standalone Prometheus Server (`9090`). |

---

## Quick Start Guide

To install Grafana, Prometheus, Node Exporter, and pre-configure all 4 Grafana Dashboards in a single command:

```bash
chmod +x install_grafana.sh
./install_grafana.sh
```

### Features in `install_grafana.sh`:
1. Installs & enables **Grafana** (`3000`).
2. Installs & enables **Prometheus** (`9090`) with scrape jobs for both Prometheus & Node Exporter targets.
3. Installs & enables **Node Exporter** (`9100`).
4. Includes service process lock (`Text file busy`) prevention on reinstall.
5. Auto-provisions Prometheus as the default data source in Grafana.
6. Auto-downloads and imports dashboards:
   - **`1860`**: Node Exporter Full (Linux Server CPU/RAM/Disk metrics)
   - **`14282`**: Docker Container Monitoring (cAdvisor)
   - **`315`**: Kubernetes Cluster Monitoring
   - **`3662`**: Prometheus 2.0 Overview
