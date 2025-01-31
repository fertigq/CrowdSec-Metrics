#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Create a dedicated user for the service
useradd -r -s /bin/false crowdsec-dashboard
usermod -aG docker crowdsec-dashboard

# Create application directory
mkdir -p /opt/crowdsec-metrics
chown crowdsec-dashboard:crowdsec-dashboard /opt/crowdsec-metrics

# Copy files
cp -r * /opt/crowdsec-metrics/
cd /opt/crowdsec-metrics

# Install dependencies
npm install --production

# Create and configure environment file
cp .env.example .env
chown crowsec-dashboard:crowsec-dashboard .env
chmod 600 .env

# Configure sudo access for metrics commands
echo "crowdsec-dashboard ALL=(ALL) NOPASSWD: /usr/bin/cscli metrics" > /etc/sudoers.d/crowdsec-dashboard
echo "crowdsec-dashboard ALL=(root) NOPASSWD: /usr/bin/docker exec crowdsec cscli metrics" >> /etc/sudoers.d/crowdsec-dashboard

# Set up the systemd service
cp crowdsec-metrics.service /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Start and enable the service
systemctl enable crowdsec-metrics
systemctl start crowdsec-metrics

# Configure firewall (assuming UFW)
ufw allow from 192.168.0.0/16 to any port 3456 proto tcp comment 'Allow CrowdSec dashboard from local network'
ufw allow from 172.16.0.0/12 to any port 3456 proto tcp comment 'Allow CrowdSec dashboard from Docker network'
ufw allow from 10.0.0.0/8 to any port 3456 proto tcp comment 'Allow CrowdSec dashboard from VPN network'

echo "Installation complete. Please edit /opt/crowdsec-metrics/.env to set your admin credentials and other configurations."
echo "Then, restart the service with: systemctl restart crowdsec-metrics"

echo "Adjusting permissions..."
chown -R crowdsec-dashboard:crowdsec-dashboard /opt/crowdsec-metrics
chmod 750 /opt/crowdsec-metrics

echo "To further restrict access, consider setting up a reverse proxy with HTTPS."
