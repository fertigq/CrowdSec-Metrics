#!/bin/bash
set -euo pipefail

# Function to display a spinner
spinner() {
  local pid=$1
  local msg=$2
  local delay=0.1
  local spinner=('|' '/' '-' '\')
  local i=0

  while kill -0 "$pid" 2>/dev/null; do
    printf "\r[%s] %s" "${spinner[i]}" "$msg"
    sleep "$delay"
    i=$(( (i+1) % 4 ))
  done
  printf "\r[✔] %s\n" "$msg"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Check root privileges
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root" >&2
  exit 1
fi

# Create dedicated user
if ! id "crowdsec-dashboard" &>/dev/null; then
  echo "Creating service user..."
  useradd -r -s /bin/false crowdsec-dashboard
  usermod -aG docker crowdsec-dashboard || echo "⚠️  Docker group not found, continuing anyway"
else
  echo "ℹ️  User 'crowdsec-dashboard' already exists"
fi

# Create application directory
APP_DIR="/opt/crowdsec-metrics"
mkdir -p "$APP_DIR"
chown crowdsec-dashboard:crowdsec-dashboard "$APP_DIR"

# Copy application files
echo "📂 Copying files from $SCRIPT_DIR to $APP_DIR..."
rsync -ah --progress --exclude=.env "$SCRIPT_DIR/" "$APP_DIR/" || {
  echo "❌ Failed to copy files" >&2
  exit 1
}

cd "$APP_DIR"

# Verify critical files exist
for file in package.json crowdsec-metrics.service .env.example; do
  if [[ ! -f "$file" ]]; then
    echo "❌ Missing required file: $file" >&2
    exit 1
  fi
done

# Install Node.js if needed
if ! command -v npm &>/dev/null; then
  echo "Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - &
  spinner $! "Configuring NodeSource"
  apt-get install -y nodejs &
  spinner $! "Installing Node.js"
fi

# Install dependencies
echo "📦 Installing npm dependencies..."
sudo -u crowdsec-dashboard npm install --production &
spinner $! "Installing packages"

# Configure environment file
if [[ ! -f .env ]]; then
  cp .env.example .env
  chown crowdsec-dashboard:crowdsec-dashboard .env
  chmod 600 .env
  echo "ℹ️  Created new .env file from example"
else
  echo "ℹ️  Existing .env file preserved"
fi

# Configure sudo access
SUDOERS_FILE="/etc/sudoers.d/crowdsec-dashboard"
if [[ ! -f "$SUDOERS_FILE" ]]; then
  echo "Configuring sudo privileges..."
  {
    echo "crowdsec-dashboard ALL=(ALL) NOPASSWD: /usr/bin/cscli metrics"
    echo "crowdsec-dashboard ALL=(root) NOPASSWD: /usr/bin/docker exec crowdsec cscli metrics"
  } > "$SUDOERS_FILE"
  chmod 440 "$SUDOERS_FILE"
else
  echo "ℹ️  Sudoers configuration already exists"
fi

# Install systemd service
SERVICE_FILE="/etc/systemd/system/crowdsec-metrics.service"
if [[ ! -f "$SERVICE_FILE" ]]; then
  cp crowdsec-metrics.service "$SERVICE_FILE"
  systemctl daemon-reload
  echo "ℹ️  Systemd service installed"
else
  echo "ℹ️  Systemd service already exists"
fi

# Enable and restart service
echo "🔄 Starting service..."
systemctl enable --now crowdsec-metrics || {
  echo "❌ Failed to start service" >&2
  systemctl status crowdsec-metrics || true
  exit 1
}

# Configure firewall
if command -v ufw &>/dev/null && ! ufw status | grep -q 3456/tcp; then
  ufw allow 3456/tcp
  echo "🔒 Added firewall rule for port 3456"
fi

# Final permissions
chown -R crowdsec-dashboard:crowdsec-dashboard "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 750 {} \;
find "$APP_DIR" -type f -exec chmod 640 {} \;

echo "✅ Installation complete"
echo "➤ Edit your configuration: sudo nano $APP_DIR/.env"
echo "➤ Check service status: systemctl status crowdsec-metrics"
echo "➤ View logs: journalctl -u crowdsec-metrics -f"
