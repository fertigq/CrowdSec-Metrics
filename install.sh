#!/bin/bash
set -euo pipefail

# Colors and styling
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Fun ASCII art
print_banner() {
  cat << "EOF"
   _____                     _ _____           
  / ____|                   | |  __ \          
 | |     _ __ _____      __| | |__) |_ _ ___ 
 | |    | '__/ _ \ \ /\ / /| |  ___/ _' / __|
 | |____| | | (_) \ V  V / | | |  | (_| \__ \
  \_____|_|  \___/ \_/\_/  |_|_|   \__,_|___/
                                             
     🛡️  Metrics Dashboard Installer 🛡️
EOF
}

# Matrix-style rain animation
matrix_rain() {
  local msg="$1"
  local cols=$(tput cols)
  local lines=5
  local chars=('0' '1' '▀' '▄' '█' '░' '▒' '▓')
  
  # Clear previous lines
  for ((i=0; i<lines; i++)); do
    echo -en "\033[A\033[K"
  done
  
  # Print message in the middle
  local padding=$(( (cols - ${#msg}) / 2 ))
  echo -en "\033[${lines}A"
  echo -en "\033[${padding}C${CYAN}${BOLD}${msg}${NC}\n"
  
  # Matrix rain effect
  for ((i=0; i<4; i++)); do
    local line=""
    for ((j=0; j<cols; j++)); do
      if ((RANDOM % 3 == 0)); then
        line+="${GREEN}${chars[$((RANDOM % ${#chars[@]}))]}"
      else
        line+=" "
      fi
    done
    echo -e "${line}${NC}"
  done
  sleep 0.1
}

# Progress bar with style
progress_bar() {
  local msg="$1"
  local duration=${2:-3}
  local cols=$(tput cols)
  local bar_size=40
  local progress=0
  
  echo -e "\n${CYAN}${BOLD}$msg${NC}"
  
  while [ $progress -le 100 ]; do
    local filled=$(($progress * bar_size / 100))
    local empty=$((bar_size - filled))
    
    printf "\r["
    printf "%${filled}s" '' | tr ' ' '█'
    printf "%${empty}s" '' | tr ' ' '░'
    printf "] ${progress}%%"
    
    progress=$((progress + 2))
    sleep $(bc -l <<< "scale=4; $duration/50")
  done
  echo -e "\n"
}

# Improved logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Main installation function
install_crowdsec_metrics() {
  clear
  print_banner
  sleep 1
  
  # Check root privileges
  if [[ $EUID -ne 0 ]]; then
    log_error "Please run as root"
    exit 1
  }
  
  # Initialize installation
  matrix_rain "Initializing CrowdSec Metrics Installation"
  sleep 1
  
  # Find CrowdSec installation
  progress_bar "Detecting CrowdSec Installation" 2
  CROWDSEC_DIR=$(dirname "$(which cscli 2>/dev/null)" || echo "")
  if [[ -z "$CROWDSEC_DIR" ]]; then
    log_error "CrowdSec installation not found!"
    exit 1
  }
  log_success "CrowdSec found at: $CROWDSEC_DIR"
  
  # Create service user
  matrix_rain "Creating Service User"
  if ! id "crowdsec-dashboard" &>/dev/null; then
    useradd -r -s /bin/false crowdsec-dashboard
    usermod -aG docker crowdsec-dashboard 2>/dev/null || log_warning "Docker group not found (optional)"
    log_success "Created user 'crowdsec-dashboard'"
  else
    log_info "User 'crowdsec-dashboard' already exists"
  fi
  
  # Setup application directory
  APP_DIR="/opt/crowdsec-metrics"
  progress_bar "Setting up application directory" 2
  mkdir -p "$APP_DIR"
  chown crowdsec-dashboard:crowdsec-dashboard "$APP_DIR"
  
  # Copy files
  matrix_rain "Deploying Application Files"
  rsync -ah --progress --exclude=.env "$(dirname "$0")/" "$APP_DIR/" || {
    log_error "Failed to copy files"
    exit 1
  }
  
  # Create .env.example
  progress_bar "Creating configuration files" 2
  ENV_EXAMPLE_PATH="${APP_DIR}/.env.example"
  if [[ ! -f "$ENV_EXAMPLE_PATH" ]]; then
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
    log_success "Created .env.example"
  fi

  # Create package.json
  matrix_rain "Creating Node.js configuration"
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
  },
  "keywords": ["crowdsec", "metrics", "dashboard", "security"],
  "author": "Your Organization",
  "license": "MIT"
}
EOL
  log_success "Created package.json"

  # Create metrics-server.js
  matrix_rain "Creating metrics server"
  cat > "${APP_DIR}/metrics-server.js" << EOL
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
  log_success "Created metrics-server.js"
  
  # Install dependencies with style
  matrix_rain "Installing Dependencies"
  cd "$APP_DIR"
  if ! npm install; then
    log_error "Failed to install dependencies"
    exit 1
  }
  log_success "Dependencies installed successfully"
  
  # Create systemd service file
  progress_bar "Creating system service" 2
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
  matrix_rain "Configuring Security Permissions"
  echo "crowdsec-dashboard ALL=(ALL) NOPASSWD: /usr/bin/cscli metrics" > "/etc/sudoers.d/crowdsec-dashboard"
  chmod 0440 "/etc/sudoers.d/crowdsec-dashboard"
  log_success "Security permissions configured"
  
  # Setup systemd service
  progress_bar "Starting system service" 2
  systemctl daemon-reload
  systemctl enable crowdsec-metrics.service
  systemctl start crowdsec-metrics.service
  
  # Final success message
  clear
  print_banner
  echo -e "\n${GREEN}${BOLD}🎉 Installation Complete! 🎉${NC}\n"
  echo -e "${CYAN}📊 Dashboard is now running!${NC}"
  echo -e "${YELLOW}➤ Check status:${NC} systemctl status crowdsec-metrics"
  echo -e "${YELLOW}➤ View logs:${NC} journalctl -u crowdsec-metrics -f\n"
}

# Run the installation
install_crowdsec_metrics
