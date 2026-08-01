#!/bin/bash
# ==============================================================================
# Jenkins LTS + Docker + Git + Nginx Reverse Proxy Installer for AL2023
# ==============================================================================

set -e

echo "=========================================================================="
echo " Starting Jenkins LTS + Docker + Nginx Installation on Amazon Linux 2023"
echo "=========================================================================="

# 1. Update DNF package manager
echo "--> Updating DNF packages..."
sudo dnf update -y

# 2. Install Java 21 LTS (Amazon Corretto), Fontconfig, Git, Docker, Nginx, Wget
echo "--> Installing Java 21, Fontconfig, Git, Docker, Nginx, and Wget..."
sudo dnf remove -y java-17-amazon-corretto 2>/dev/null || true
sudo dnf install -y java-21-amazon-corretto fontconfig wget git docker nginx

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

# 7. Configure Systemd Override & Directory Permissions for Jenkins
echo "--> Configuring Systemd override & directory permissions..."
JAVA_HOME_DIR=$(dirname $(dirname "$REAL_JAVA"))
sudo mkdir -p /etc/systemd/system/jenkins.service.d/

cat << EOF | sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null
[Service]
Environment="JAVA_HOME=${JAVA_HOME_DIR}"
Environment="JENKINS_JAVA_CMD=${REAL_JAVA}"
EOF

sudo mkdir -p /var/lib/jenkins /var/log/jenkins /var/cache/jenkins
sudo chown -R jenkins:jenkins /var/lib/jenkins /var/log/jenkins /var/cache/jenkins

# 8. Start Jenkins Service
echo "--> Enabling and starting Jenkins service..."
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

# 9. Configure Nginx as Reverse Proxy (Port 80 -> Port 8080)
echo "--> Configuring Nginx reverse proxy for Jenkins on Port 80..."
cat << 'EOF' | sudo tee /etc/nginx/nginx.conf > /dev/null
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access_log main;

    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;

        location / {
            proxy_pass          http://127.0.0.1:8080;
            proxy_set_header    Host $host;
            proxy_set_header    X-Real-IP $remote_addr;
            proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header    X-Forwarded-Proto $scheme;
            proxy_read_timeout  90;
        }
    }
}
EOF

# 10. Enable & Start Nginx Service
echo "--> Enabling and starting Nginx service..."
sudo systemctl enable --now nginx
sudo systemctl restart nginx

# 11. Retrieve Public IP & Initial Admin Password
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
echo " 🎉 Jenkins + Docker + Nginx Installed Successfully!"
echo "=========================================================================="
echo " Access Jenkins Web UI at:"
echo "   - Main URL (via Nginx Port 80):  http://${PUBLIC_IP}"
echo "   - Direct Port 8080:              http://${PUBLIC_IP}:8080"
echo "--------------------------------------------------------------------------"
echo " Initial Admin Password:"
echo " ${ADMIN_PASS}"
echo "=========================================================================="
