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

# Cozy loading animation
cozy_loading() {
  local msg="$1"
  local chars='⭐ 🌙 ✨ 🌟 '
  
  echo -e "\n${CYAN}${BOLD}$msg${NC}"
  for ((i = 0; i < 3; i++)); do
    for (( j = 0; j < ${#chars}; j++ )); do
      echo -en "\r${chars:$j:1} "
      sleep 0.2
    done
  done
  echo -e "\n"
}

# Progress indicator
progress_bar() {
  local msg="$1"
  local duration=${2:-3}
  
  echo -e "\n${CYAN}${BOLD}$msg${NC}"
  echo -ne "╭"
  for ((i = 0; i < 20; i++)); do echo -ne "─"; done
  echo -e "╮"
  echo -ne "│"
  for ((i = 0; i < 20; i++)); do
    echo -ne "✿"
    sleep $(bc -l <<< "scale=4; $duration/20")
  done
  echo -e "│"
  echo -ne "╰"
  for ((i = 0; i < 20; i++)); do echo -ne "─"; done
  echo -e "╯\n"
}

# Logging functions with cute indicators
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
  
  # Check root privileges
  if [[ $EUID -ne 0 ]]; then
    log_error "Please run as root"
    exit 1
  }
  
  # Check for Node.js
  if ! command -v node &> /dev/null; then
    log_error "Node.js is not installed! Please install Node.js first."
    exit 1
  }
  
  # Initialize installation
  cozy_loading "Starting Installation..."
  sleep 1
  
  [... rest of the installation script remains the same until metrics-server.js creation ...]

  # Create metrics-server.js with fixed logging
  cozy_loading "Creating metrics server"
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
  logger.info(\`CrowdSec Metrics Dashboard running at http://\${host}:\${port}\`);
});
EOL

  [... rest of the installation script remains the same ...]
}

# Run the installation
install_crowdsec_metrics
