#!/bin/bash
set -euo pipefail

# Cosmos Cloud Instance User Data Script
# This script initializes the EC2 instance and installs Cosmos Cloud
# Generated: 2025-12-28 15:30:49 UTC

# Update system packages
apt-get update
apt-get upgrade -y

# Install required dependencies
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    jq \
    awscli \
    docker.io \
    docker-compose \
    python3 \
    python3-pip \
    nodejs \
    npm

# Enable and start Docker service
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install Docker Compose if not included
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Create application directories
mkdir -p /opt/cosmos-cloud
mkdir -p /var/log/cosmos-cloud
mkdir -p /etc/cosmos-cloud

# Set proper permissions
chown -R ubuntu:ubuntu /opt/cosmos-cloud
chown -R ubuntu:ubuntu /var/log/cosmos-cloud
chown -R ubuntu:ubuntu /etc/cosmos-cloud

# Clone or pull Cosmos Cloud repository
cd /opt/cosmos-cloud
if [ -d .git ]; then
    git pull origin main
else
    git clone https://github.com/groblochon/cosmos-cloud.git .
fi

# Install Python dependencies if requirements.txt exists
if [ -f requirements.txt ]; then
    pip3 install -r requirements.txt
fi

# Install Node.js dependencies if package.json exists
if [ -f package.json ]; then
    npm install
fi

# Create systemd service file for Cosmos Cloud
cat > /etc/systemd/system/cosmos-cloud.service <<'EOF'
[Unit]
Description=Cosmos Cloud Service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/cosmos-cloud
ExecStart=/usr/bin/docker-compose up
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
systemctl daemon-reload

# Enable and start Cosmos Cloud service
systemctl enable cosmos-cloud.service
systemctl start cosmos-cloud.service

# Log installation completion
echo "Cosmos Cloud instance initialization completed at $(date -u +'%Y-%m-%d %H:%M:%S UTC')" >> /var/log/cosmos-cloud/setup.log

# Output status
echo "================================"
echo "Cosmos Cloud Setup Complete"
echo "================================"
echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "Service Status: $(systemctl is-active cosmos-cloud.service)"
echo "Log Location: /var/log/cosmos-cloud/setup.log"
