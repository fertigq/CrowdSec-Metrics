#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Create a dedicated user for the service
if ! id "crowdsec-dashboard" &>/dev/null; then
    useradd -r -s /bin/false crowdsec-dashboard
    echo "Created crowdsec-dashboard user"
else
    echo "User crowdsec-dashboard already exists, skipping creation"
fi

usermod -aG docker crowdsec-dashboard

# Create application directory
mkdir -p /opt/crowdsec-metrics
chown crowdsec-dashboard:crowdsec-dashboard /opt/crowdsec-metrics

# Copy files (from the directory where the script is located)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cp -r "${SCRIPT_DIR}"/* /opt/crowdsec-metrics/
cd /opt/crowdsec-metrics

# Verify npm exists
if ! command -v npm &> /dev/null; then
    echo "ERROR: npm not found! Please install Node.js and npm first"
    exit 1
fi

# Install dependencies
sudo -u crowdsec-dashboard npm install --production

# Create and configure environment file
if [ -f ".env.example" ]; then
    cp .env.example .env
    chown crowdsec-dashboard:crowdsec-dashboard .env
    chmod 600 .env
else
    echo "WARNING: .env.example not found, creating empty .env file"
    touch .env
    chown crowdsec-dashboard:crowdsec-dashboard .env
    chmod 600 .env
fi

# Configure sudo access for metrics commands
echo "crowdsec-dashboard ALL=(ALL) NOPASSWD: /usr/bin/cscli metrics" > /etc/sudoers.d/crowdsec-dashboard
echo "crowdsec-dashboard ALL=(root) NOPASSWD: /usr/bin/docker exec crowdsec cscli metrics" >> /etc/sudoers.d/crowdsec-dashboard
chmod 440 /etc/sudoers.d/crowdsec-dashboard

# Set up the systemd service
cp crowdsec-metrics.service /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Start and enable the service
systemctl enable crowdsec-metrics
systemctl restart crowdsec-metrics  # Changed from 'start' to 'restart'

# Configure firewall (only if ufw is available)
if command -v ufw &> /dev/null; then
    ufw allow 3456
    echo "Firewall rule added for port 3456"
else
    echo "Note: ufw not found, you may need to configure your firewall manually"
fi

echo "Installation complete. Please edit /opt/crowdsec-metrics/.env to set your admin credentials and other configurations."
echo "You can restart the service with: systemctl restart crowdsec-metrics"

echo "Adjusting permissions..."
chown -R crowdsec-dashboard:crowdsec-dashboard /opt/crowdsec-metrics
chmod 750 /opt/crowdsec-metrics

echo "To further restrict access, consider setting up a reverse proxy with HTTPS."
