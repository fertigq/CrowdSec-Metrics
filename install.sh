#!/bin/bash

# Function to display a spinner
spinner() {
  local pid=$1
  local delay=0.1
  local spinner=( '|' '/' '-' '\' )

  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    for i in "${spinner[@]}"; do
      printf "\r[%c] %s" "$i" "Installing dependencies..."
      sleep $delay
    done
  done
  printf "\r[✔] %s\n" "Installation complete!"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if user already exists
if id "crowdsec-dashboard" &>/dev/null; then
  echo "User 'crowdsec-dashboard' already exists"
else
  # Create a dedicated user for the service
  useradd -r -s /bin/false crowdsec-dashboard
  usermod -aG docker crowdsec-dashboard
fi

# Create application directory
mkdir -p /opt/crowdsec-metrics
chown crowdsec-dashboard:crowdsec-dashboard /opt/crowdsec-metrics

# Copy files
for file in *; do
  if [ ! -e "/opt/crowdsec-metrics/$file" ]; then
    cp -r "$file" /opt/crowdsec-metrics/
  fi
done
cd /opt/crowdsec-metrics

# Install Node.js and npm if not already installed
if ! command -v npm &> /dev/null; then
  echo "npm not found, installing Node.js and npm..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

# Install dependencies with spinner
npm install --production &
spinner $!

# Create and configure environment file
if [ -e ".env.example" ]; then
  cp .env.example .env
  chown crowdsec-dashboard:crowdsec-dashboard .env
  chmod 600 .env
else
  echo ".env.example file not found"
  exit 1
fi

# Configure sudo access for metrics commands
echo "crowdsec-dashboard ALL=(ALL) NOPASSWD: /usr/bin/cscli metrics" > /etc/sudoers.d/crowdsec-dashboard
echo "crowdsec-dashboard ALL=(root) NOPASSWD: /usr/bin/docker exec crowdsec cscli metrics" >> /etc/sudoers.d/crowdsec-dashboard

# Set up the systemd service
if [ ! -e "/etc/systemd/system/crowdsec-metrics.service" ]; then
  cp crowdsec-metrics.service /etc/systemd/system/
fi

# Reload systemd
systemctl daemon-reload

# Start and enable the service
systemctl enable crowdsec-metrics
systemctl start crowdsec-metrics

# Configure firewall (assuming UFW)
ufw allow 3456

echo "Installation complete. Please edit /opt/crowdsec-metrics/.env to set your admin credentials and other configurations."
echo "Then, restart the service with: systemctl restart crowdsec-metrics"

echo "Adjusting permissions..."
chown -R crowdsec-dashboard:crowdsec-dashboard /opt/crowdsec-metrics
chmod 750 /opt/crowdsec-metrics

echo "To further restrict access, consider setting up a reverse proxy with HTTPS."
