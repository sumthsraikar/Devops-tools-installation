# DevOps Tools Installation Scripts

Automated shell scripts for installing DevOps and monitoring tools on **Amazon Linux 2023**.

## Included Scripts

| Tool / Script | Script File | Description / Ports |
| :--- | :--- | :--- |
| **⚡ Master All-in-One Installer** | `setup_all_monitoring.sh` | Installs **Prometheus**, **Node Exporter**, **Grafana**, connects data source, and auto-imports dashboards **1860**, **14282**, **315**, **3662**. |
| **Prometheus** | `install_prometheus.sh` | Prometheus Server (`9090`) |
| **Grafana** | `install_grafana.sh` | Grafana Web UI (`3000`) |
| **Node Exporter** | `install_node_exporter.sh` | Node Exporter Metrics Collector (`9100`) |

---

## Quick Start (Recommended Master Script)

To install everything in a single step with pre-configured Grafana dashboards:

```bash
chmod +x setup_all_monitoring.sh
./setup_all_monitoring.sh
```

### What `setup_all_monitoring.sh` does automatically:
1. Installs **Prometheus** (`9090`) & configures systemd.
2. Installs **Node Exporter** (`9100`) & configures systemd.
3. Configures Prometheus to scrape Node Exporter (`localhost:9100`).
4. Installs **Grafana** (`3000`).
5. **Auto-provisions Prometheus** as the default data source in Grafana.
6. **Auto-downloads and imports all 4 dashboards**:
   - `1860` - **Node Exporter Full** (Linux Server metrics)
   - `14282` - **Docker Container Monitoring (cAdvisor)**
   - `315` - **Kubernetes Cluster Monitoring**
   - `3662` - **Prometheus 2.0 Overview**
