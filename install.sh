#!/bin/bash
set -euo pipefail

# Fancy spinner with colors
spinner() {
  local pid=$1
  local msg=$2
  local delay=0.1
  local spinner=('🌑' '🌒' '🌓' '🌔' '🌕' '🌖' '🌗' '🌘')
  local color='\033[1;36m'  # Cyan
  local reset='\033[0m'
  local i=0

  while kill -0 "$pid" 2>/dev/null; do
    printf "\r${color}${spinner[i]} %s...${reset}" "$msg"
    sleep "$delay"
    i=$(( (i+1) % 8 ))
  done
  printf "\r✅ ${color}%s complete!${reset}\n" "$msg"
}

# Colorful echo functions
info() {
  echo -e "\033[1;34m[ℹ️ INFO]\033[0m $1"
}

success() {
  echo -e "\033[1;32m[✅ SUCCESS]\033[0m $1"
}

error() {
  echo -e "\033[1;31m[❌ ERROR]\033[0m $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Check root privileges
if [[ $EUID -ne 0 ]]; then
  error "Please run as root" >&2
  exit 1
fi

# Find CrowdSec installation directory
CROWDSEC_DIR=$(dirname "$(which cscli)")
if [[ -z "$CROWDSEC_DIR" ]]; then
  error "CrowdSec installation not found" >&2
  exit 1
fi

# Create dedicated user
if ! id "crowdsec-dashboard" &>/dev/null; then
  info "Creating service user..."
  useradd -r -s /bin/false crowdsec-dashboard
  usermod -aG docker crowdsec-dashboard || info "Docker group not found, continuing anyway"
else
  info "User 'crowdsec-dashboard' already exists"
fi

# Create application directory
APP_DIR="/opt/crowdsec-metrics"
mkdir -p "$APP_DIR"
chown crowdsec-dashboard:crowdsec-dashboard "$APP_DIR"

# Copy application files
info "Copying files from $SCRIPT_DIR to $APP_DIR..."
rsync -ah --progress --exclude=.env "$SCRIPT_DIR/" "$APP_DIR/" || {
  error "Failed to copy files" >&2
  exit 1
}

cd "$APP_DIR"

# Create .env.example if not exists
ENV_EXAMPLE_PATH="${APP_DIR}/.env.example"
if [[ ! -f "$ENV_EXAMPLE_PATH" ]]; then
  info "Creating .env.example..."
  cat > "$ENV_EXAMPLE_PATH" << EOL
# CrowdSec Metrics Dashboard Configuration

# Server Port (optional, default: 3456)
PORT=3456

# Logging Level (optional: debug, info, warn, error)
LOG_LEVEL=info

# Optional: Additional CrowdSec metrics configuration
METRICS_INTERVAL=60
EOL
fi

# Determine the correct path for package.json and metrics-server.js
PACKAGE_JSON_PATH="${APP_DIR}/package.json"
METRICS_SERVER_PATH="${APP_DIR}/metrics-server.js"

# Create package.json
info "Creating package.json in ${PACKAGE_JSON_PATH}..."
cat > "$PACKAGE_JSON_PATH" << EOL
{
  "name": "crowdsec-metrics-dashboard",
  "version": "1.0.0",
  "description": "Dashboard for CrowdSec metrics and monitoring",
  "main": "metrics-server.js",
  "scripts": {
    "start": "node metrics-server.js",
    "dev": "nodemon metrics-server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "dotenv": "^16.3.1",
    "axios": "^1.6.2",
    "winston": "^3.8.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "engines": {
    "node": ">=18.0.0"
  },
  "keywords": ["crowdsec", "metrics", "dashboard", "security"],
  "author": "Your Organization",
  "license": "MIT"
}
EOL

# Create metrics-server.js with improved logging
info "Creating metrics-server.js in ${METRICS_SERVER_PATH}..."
cat > "$METRICS_SERVER_PATH" << EOL
require('dotenv').config();
const express = require('express');
const { exec } = require('child_process');
const winston = require('winston');

// Configure logging
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.colorize(),
    winston.format.printf(({ timestamp, level, message }) => {
      return \`[\${timestamp}] \${level}: \${message}\`;
    })
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'metrics-dashboard.log' })
  ]
});

const app = express();
const port = process.env.PORT || 3456;

app.get('/metrics', (req, res) => {
  exec('sudo cscli metrics', (error, stdout, stderr) => {
    if (error) {
      logger.error(\`Metrics retrieval failed: \${error.message}\`);
      return res.status(500).json({ error: error.message });
    }
    logger.info('Metrics retrieved successfully');
    res.json({ metrics: stdout });
  });
});

app.listen(port, () => {
  logger.info(\`CrowdSec Metrics Dashboard running on port \${port}\`);
});
EOL

# Install Node.js dependencies
info "Installing Node.js dependencies..."
(npm install) & spinner $! "Installing dependencies"

# Create systemd service file
SERVICE_FILE="/etc/systemd/system/crowdsec-metrics.service"
info "Creating systemd service file at ${SERVICE_FILE}..."
cat > "$SERVICE_FILE" << EOL
[Unit]
Description=CrowdSec Metrics Dashboard
After=network.target

[Service]
ExecStart=/usr/bin/node ${APP_DIR}/metrics-server.js
Restart=always
User=crowdsec-dashboard
Environment=NODE_ENV=production
WorkingDirectory=${APP_DIR}

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable crowdsec-metrics.service
systemctl start crowdsec-metrics.service

# Configure sudoers for the crowdsec-dashboard user
SUDOERS_FILE="/etc/sudoers.d/crowdsec-dashboard"
info "Configuring sudoers for crowdsec-dashboard..."
echo "crowdsec-dashboard ALL=(ALL) NOPASSWD: /usr/bin/cscli metrics" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"

success "Installation complete!"
info "📍 Package.json created at: $PACKAGE_JSON_PATH"
info "📍 Metrics server created at: $METRICS_SERVER_PATH"
info "➤ Check service status: systemctl status crowdsec-metrics"
info "➤ View logs: journalctl -u crowdsec-metrics -f"
