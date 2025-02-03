#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Create directory
mkdir -p /opt/crowdsec-metrics
cd /opt/crowdsec-metrics

# Copy files
cp server.js /opt/crowdsec-metrics/
mkdir -p /opt/crowdsec-metrics/public
cp public/index.html /opt/crowdsec-metrics/public/

# Install dependencies
npm init -y
npm install express dotenv

# Create .env file
cat > /opt/crowdsec-metrics/.env << EOL
PORT=3456
HOST=0.0.0.0
EOL

# Create systemd service file
cat > /etc/systemd/system/crowdsec-metrics.service << EOL
[Unit]
Description=CrowdSec Metrics Dashboard
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/crowdsec-metrics/server.js
Restart=always
User=root
Environment=NODE_ENV=production
WorkingDirectory=/opt/crowdsec-metrics

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable crowdsec-metrics.service
systemctl start crowdsec-metrics.service

echo "Installation complete. Access the dashboard at http://your-server-ip:3456"

