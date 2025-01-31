#!/bin/bash
set -euo pipefail

# Colors and styling
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Cute ASCII art
print_banner() {
  cat << "EOF"
  .・。.・゜✭・.・✫・゜・。.
   ━━━━━━━━━━━━━━━━━━
    🌸 CrowdSec Metrics 🌸
   ━━━━━━━━━━━━━━━━━━
  .・。.・゜✭・.・✫・゜・。.
EOF
}

# Get IP address
get_ip_address() {
  local default_ip="0.0.0.0"
  echo -e "${CYAN}${BOLD}Enter your server IP address [default: ${default_ip}]: ${NC}"
  read -r server_ip
  SERVER_IP=${server_ip:-$default_ip}
}

# Cozy loading animation
cozy_loading() {
  local msg="$1"
  echo -e "\n${CYAN}${BOLD}$msg${NC}"
  for ((i = 0; i < 3; i++)); do
    echo -ne "\r⭐ "
    sleep 0.2
    echo -ne "\r🌙 "
    sleep 0.2
    echo -ne "\r✨ "
    sleep 0.2
    echo -ne "\r🌟 "
    sleep 0.2
  done
  echo -e "\n"
}

# Progress indicator
progress_bar() {
  local msg="$1"
  echo -e "\n${CYAN}${BOLD}$msg${NC}"
  echo -ne "╭"
  for ((i = 0; i < 20; i++)); do echo -ne "─"; done
  echo -e "╮"
  echo -ne "│"
  for ((i = 0; i < 20; i++)); do
    echo -ne "✿"
    sleep 0.1
  done
  echo -e "│"
  echo -ne "╰"
  for ((i = 0; i < 20; i++)); do echo -ne "─"; done
  echo -e "╯\n"
}

# Logging functions
log_info() {
  echo -e "${BLUE}[🌟]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[🌸]${NC} $1"
}

log_error() {
  echo -e "${RED}[❌]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[⚡]${NC} $1"
}

# Main installation function
install_crowdsec_metrics() {
  clear
  print_banner
  sleep 1
  
  # Get IP address from user
  get_ip_address
  
  # Check root privileges
  if [[ $EUID -ne 0 ]]; then
    log_error "Please run as root"
    exit 1
  }
  
  # Initialize installation
  cozy_loading "Starting Installation..."
  
  # Find CrowdSec installation
  progress_bar "Detecting CrowdSec Installation"
  CROWDSEC_DIR=$(dirname "$(which cscli 2>/dev/null)" || echo "")
  if [[ -z "$CROWDSEC_DIR" ]]; then
    log_error "CrowdSec installation not found!"
    exit 1
  }
  log_success "CrowdSec found at: $CROWDSEC_DIR"
  
  # Create service user
  cozy_loading "Creating Service User"
  if ! id "crowdsec-dashboard" &>/dev/null; then
    useradd -r -s /bin/false crowdsec-dashboard
    usermod -aG docker crowdsec-dashboard 2>/dev/null || log_warning "Docker group not found (optional)"
    log_success "Created user 'crowdsec-dashboard'"
  else
    log_info "User 'crowdsec-dashboard' already exists"
  fi
  
  # Setup application directory
  APP_DIR="/opt/crowdsec-metrics"
  progress_bar "Setting up application directory"
  mkdir -p "$APP_DIR"
  chown crowdsec-dashboard:crowdsec-dashboard "$APP_DIR"
  
  # Copy files
  cozy_loading "Deploying Application Files"
  rsync -ah --progress --exclude=.env "$(dirname "$0")/" "$APP_DIR/" || {
    log_error "Failed to copy files"
    exit 1
  }
  
  # Create .env.example
  progress_bar "Creating configuration files"
  ENV_EXAMPLE_PATH="${APP_DIR}/.env.example"
  if [[ ! -f "$ENV_EXAMPLE_PATH" ]]; then
    cat > "$ENV_EXAMPLE_PATH" << EOL
# CrowdSec Metrics Dashboard Configuration

# Server Host and Port
HOST=${SERVER_IP}
PORT=3456

# Logging Level (optional: debug, info, warn, error)
LOG_LEVEL=info

# Optional: Additional CrowdSec metrics configuration
METRICS_INTERVAL=60
EOL
    log_success "Created .env.example"
  fi

  # Create package.json
  cozy_loading "Creating Node.js configuration"
  cat > "${APP_DIR}/package.json" << EOL
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
  }
}
EOL
  log_success "Created package.json"

  # Create metrics-server.js
  cozy_loading "Creating metrics server"
  cat > "${APP_DIR}/metrics-server.js" << EOL
require('dotenv').config();
const express = require('express');
const { exec } = require('child_process');
const winston = require('winston');

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
const host = process.env.HOST || '${SERVER_IP}';
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
  logger.info(\`CrowdSec Metrics Dashboard running at http://\${host}:\${port}\`);
});
EOL
  log_success "Created metrics-server.js"
  
  # Install dependencies
  cozy_loading "Installing Dependencies"
  cd "$APP_DIR"
  if ! npm install; then
    log_error "Failed to install dependencies"
    exit 1
  fi
  log_success "Dependencies installed successfully"
  
  # Create systemd service file
  progress_bar "Creating system service"
  cat > "/etc/systemd/system/crowdsec-metrics.service" << EOL
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
  log_success "Created systemd service file"

  # Configure sudoers
  cozy_loading "Configuring Security Permissions"
  echo "crowdsec-dashboard ALL=(ALL) NOPASSWD: /usr/bin/cscli metrics" > "/etc/sudoers.d/crowdsec-dashboard"
  chmod 0440 "/etc/sudoers.d/crowdsec-dashboard"
  log_success "Security permissions configured"
  
  # Setup systemd service
  progress_bar "Starting system service"
  systemctl daemon-reload
  systemctl enable crowdsec-metrics.service
  systemctl start crowdsec-metrics.service
  
  # Final success message
  clear
  print_banner
  echo -e "\n${GREEN}${BOLD}✨ Installation Complete! ✨${NC}\n"
  echo -e "${CYAN}🌸 Dashboard is now running at: http://${SERVER_IP}:3456${NC}"
  echo -e "${YELLOW}➤ Check status:${NC} systemctl status crowdsec-metrics"
  echo -e "${YELLOW}➤ View logs:${NC} journalctl -u crowdsec-metrics -f\n"
}

# Run the installation
install_crowdsec_metrics
