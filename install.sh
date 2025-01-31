#!/bin/bash

# Function to display a spinner
spinner() {
  local pid=$1
  local delay=0.1
  local spinner=( '|' '/' '-' '\' )

  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    for i in "${spinner[@]}"; do
      printf "\r[%c] %s" "$i" "$2"
      sleep $delay
    done
  done
  printf "\r[✔] %s\n" "$2"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if user already exists
if ! id "crowdsec-dashboard" &>/dev/null; then
  useradd -r -s /bin/false crowdsec-dashboard
  usermod -aG docker crowdsec-dashboard
else
  echo "User 'crowdsec-dashboard' already exists"
fi

# Create application directory if it doesn't exist
if [ ! -d "/opt/crowdsec-metrics" ]; then
  mkdir -p /opt/crowdsec-metrics
  chown crowdsec-dashboard:crowdsec-dashboard /opt/crowdsec-metrics
else
  echo "Directory /opt/crowdsec-metrics already exists"
fi

# Copy files if they don't already exist in the destination
for file in *; do
  if [ ! -e "/opt/crowdsec-metrics/$file" ]; then
    cp -r "$file" /opt/crowdsec-metrics/
  fi
done
cd /opt/crowdsec-metrics

# Install Node.js and npm if not already installed
if ! command -v npm &> /dev/null; then
  echo "npm not found, installing Node.js and npm..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - &
  spinner $! "Setting up NodeSource repository"
  sudo apt-get install -y nodejs &
  spinner $! "Installing Node.js"
else
  echo "npm already installed"
fi

# Check if package.json exists
if [ -e "package.json" ]; then
  npm install --production &
  spinner $! "Installing dependencies"
else
  echo "package.json not found. Please ensure it is present in the directory."
  exit 1
fi

# Create and configure environment file if .env.example exists
if [ -e ".env.example" ]; then
  if [ ! -e ".env" ]; then
    cp .env.example .env
    chown crowdsec-dashboard:crowdsec-dashboard .env
    chmod 600 .env
  else
    echo ".env file already exists"
  fi
else
  echo ".env.example file not found"
  exit 1
fi

# Configure sudo access for metrics commands if not already configured
if [ ! -e "/etc/sudoers.d/crowdsec-dashboard" ]; then
  echo "crowdsec-dashboard ALL=(ALL) NOPASSWD: /usr/bin/cscli metrics" > /etc/sudoers.d/crowdsec-dashboard
  echo "crowdsec-dashboard ALL=(root) NOPASSWD: /usr/bin/docker exec crowdsec cscli metrics" >> /etc/sudoers.d/crowdsec-dashboard
else
  echo "Sudoers configuration for crowdsec-dashboard already exists"
fi

# Set up the systemd service if it doesn't already exist
if [ ! -e "/etc/systemd/system/crowdsec-metrics.service" ]; then
  cp crowdsec-metrics.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable crowdsec-metrics
  systemctl start crowdsec-metrics
else
  echo "Systemd service for crowdsec-metrics already exists"
fi

# Configure firewall (assuming UFW) if the rule doesn't already exist
if ! ufw status | grep -q "3456"; then
  ufw allow 3456
else
  echo "Firewall rule for port 3456 already exists"
fi

echo "Installation complete. Please edit /opt/crowdsec-metrics/.env to set your admin credentials and other configurations."
echo "Then, restart the service with: systemctl restart crowdsec-metrics"

echo "Adjusting permissions..."
chown -R crowdsec-dashboard:crowdsec-dashboard /opt/crowdsec-metrics
chmod 750 /opt/crowdsec-metrics

echo "To further restrict access, consider setting up a reverse proxy with HTTPS."
