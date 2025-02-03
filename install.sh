#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Create directory and user
mkdir -p /opt/crowdsec-metrics
useradd -r -s /bin/false crowdsec-dashboard

# Copy files
cp server.js /opt/crowdsec-metrics/
mkdir -p /opt/crowdsec-metrics/public
cp -r public/* /opt/crowdsec-metrics/public/
cp -r src /opt/crowdsec-metrics/

# Install dependencies
cd /opt/crowdsec-metrics
npm init -y
npm install express dotenv react react-dom react-chartjs-2 chart.js

# Build React app
npm run build

# Create .env file
cat > /opt/crowdsec-metrics/.env << EOL
PORT=3456
HOST=0.0.0.0
EOL

# Copy systemd service file
cp crowdsec-metrics.service /etc/systemd/system/

# Set permissions
chown -R crowdsec-dashboard:crowdsec-dashboard /opt/crowdsec-metrics
chmod 750 /opt/crowdsec-metrics

# Configure sudo access for metrics commands
echo "crowdsec-dashboard ALL=(ALL) NOPASSWD: /usr/bin/cscli metrics, /usr/bin/docker exec crowdsec cscli metrics" > /etc/sudoers.d/crowdsec-dashboard
chmod 0440 /etc/sudoers.d/crowdsec-dashboard

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable crowdsec-metrics.service
systemctl start crowdsec-metrics.service

echo "Installation complete. Access the dashboard at http://your-server-ip:3456"

