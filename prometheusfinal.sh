#!/bin/bash

# Install Prometheus
# sudo yum update -y
# sudo amazon-linux-extras install -y epel
# sudo yum install -y wget
# sudo apt update -y
# sudo apt install nginx -y
# sudo apt install wget -y 
# sudo systemctl start nginx 
# sudo systemctl enable nginx
# PROMETHEUS_VERSION=2.30.3
# wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
# tar -xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
# sudo mv prometheus-${PROMETHEUS_VERSION}.linux-amd64 /opt/prometheus
# sudo ln -s /opt/prometheus/prometheus-${PROMETHEUS_VERSION}.linux-amd64 /opt/prometheus/latest
# sudo chown -R ec2-user:ec2-user /opt/prometheuss
sudo apt-get update -y
sudo apt-get install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
# Download and extract Prometheus
sudo wget https://github.com/prometheus/prometheus/releases/download/v2.33.0/prometheus-2.33.0.linux-amd64.tar.gz
sudo tar xvfz prometheus-2.33.0.linux-amd64.tar.gz
sudo mv prometheus-2.33.0.linux-amd64 /opt/

# Create a Prometheus configuration file
cat > prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
EOF

# Create a systemd service file for Prometheus
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus-2.33.0.linux-amd64/prometheus \
  --config.file=/opt/prometheus-2.33.0.linux-amd64/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus-2.33.0.linux-amd64/data

[Install]
WantedBy=multi-user.target
EOF

# Create a user for Prometheus
sudo useradd --no-create-home --shell /bin/false prometheus

# Set the correct ownership and permissions for the Prometheus installation directory
sudo chown -R prometheus:prometheus /opt/prometheus-2.33.0.linux-amd64
sudo chmod -R 755 /opt/prometheus-2.33.0.linux-amd64

# Reload systemd and start the Prometheus service
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

# Install Node Exporter
NODE_EXPORTER_VERSION=1.2.2
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar -xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
sudo chown root:root /usr/local/bin/node_exporter
sudo mkdir -p /opt/var/prometheus/logs

# Configure Node Exporter as a daemon service
cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter
StandardOutput=append:/opt/var/prometheus/logs/node_exporter.log
StandardError=append:/opt/var/prometheus/logs/node_exporter.log

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# Set up log rotation for Node Exporter
#cat <<EOF | sudo tee /etc/logrotate.d/node_exporter
# /opt/var/prometheus/logs/*.log {
#   missingok
#   notifempty
#   size 5M
#   compress
#   delaycompress

# EOF
cat <<EOF | sudo tee /opt/var/prometheus/logdel.sh
#!/bin/bash

LOG_DIR="/opt/var/prometheus/logs"
MAX_AGE_IN_HOURS=5

# Set debug mode
set -x

# Check directory permissions
ls -ld "$LOG_DIR"

# Find log files older than MAX_AGE_IN_HOURS and delete them
find "$LOG_DIR" -type f -name "*.log" -mmin +$((MAX_AGE_IN_HOURS*60)) -print
find "$LOG_DIR" -type f -name "*.log" -mmin +$((MAX_AGE_IN_HOURS*60)) -exec rm {} \;

EOF
sudo chmod 770 /opt/var/prometheus/logdel.sh

cat <<EOF | sudo tee /opt/var/prometheus/cron.sh
#!/bin/bash

# Create a new crontab entry to run the command every 5 hours
(crontab -l 2>/dev/null; echo "0 */5 * * * /opt/var/prometheus/logdel.sh") | crontab -
EOF
sudo chmod 770 /opt/var/prometheus/cron.sh
sudo ./opt/var/prometheus/cron.sh
