#!/bin/bash
set -euo pipefail

# Hacker-style animation function
hacker_animation() {
  local msg=$1
  local chars=('|' '/' '-' '\')
  local hacker_chars=('01' '10' '001' '110' '0101' '1010')
  local delay=0.1
  local i=0
  local j=0

  while true; do
    printf "\r\033[1;32m[%s] \033[1;37m%s \033[1;32m%s\033[0m" "${hacker_chars[j]}" "$msg" "${chars[i]}"
    sleep "$delay"
    i=$(( (i+1) % ${#chars[@]} ))
    j=$(( (j+1) % ${#hacker_chars[@]} ))
  done
}

# Colorful echo functions
info() {
  echo -e "\033[1;34m[INFO]\033[0m $1"
}

success() {
  echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Fail log function
fail_log() {
  local log_file="/tmp/crowdsec_metrics_install_fail.log"
  echo "Installation failed at $(date)" > "$log_file"
  echo "Current directory: $(pwd)" >> "$log_file"
  echo "Error message: $1" >> "$log_file"
  error "Installation failed. Check $log_file for details."
}

# Trap for cleanup
trap 'kill $ANIM_PID 2>/dev/null' EXIT

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Check root privileges
if [[ $EUID -ne 0 ]]; then
  fail_log "Please run as root"
  exit 1
fi

# Find CrowdSec installation directory
CROWDSEC_DIR=$(dirname "$(which cscli)")
if [[ -z "$CROWDSEC_DIR" ]]; then
  fail_log "CrowdSec installation not found"
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
  fail_log "Failed to copy files"
  exit 1
}

cd "$APP_DIR"

# Create .env.example if not exists
ENV_EXAMPLE_PATH="${APP_DIR}/.env.example"
if [[ ! -f "$ENV_EXAMPLE_PATH" ]]; then
  info "Creating .env.example..."
  cat > "$ENV_EXAMPLE_PATH" << EOL
# CrowdSec Metrics Dashboard Configuration

# Server Host and Port
HOST=10.10.10.72
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
const host = process.env.HOST || '10.10.10.72';
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

app.listen(port, host, () => {
  logger.info(\`CrowdSec Metrics Dashboard running on http://\${host}:\${port}\`);
});
EOL

# Install Node.js dependencies
info "Installing Node.js dependencies..."
hacker_animation "Installing dependencies" &
ANIM_PID=$!
npm install
kill $ANIM_PID
wait $ANIM_PID 2>/dev/null
echo -e "\r\033[K\033[1;32m[SUCCESS]\033[0m Dependencies installed successfully"

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
