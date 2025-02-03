#!/usr/bin/env bash

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ASCII art banner
print_banner() {
    echo -e "${BLUE}"
    echo '  ____                     _ ____             __  __      _        _          '
    echo ' / ___|_ __ _____      __| / ___|  ___  ___ |  \/  | ___| |_ _ __(_) ___ ___ '
    echo '| |   |  __/ _ \ \ /\ / /| \___ \ / _ \/ __|| |\/| |/ _ \ __| '__| |/ __/ __|'
    echo '| |___| | | (_) \ V  V / | |___) |  __/ (__ | |  | |  __/ |_| |  | | (__\__ \'
    echo ' \____|_|  \___/ \_/\_/  |_|____/ \___|\___||_|  |_|\___|\__|_|  |_|\___|___/'
    echo -e "${NC}"
    echo -e "${BOLD}Dashboard Installer${NC}\n"
}

# Error handling function
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Success message function
success_msg() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Info message function
info_msg() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Warning message function
warning_msg() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if running with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "Please run with sudo privileges"
    fi
}

# Check system requirements
check_requirements() {
    info_msg "Checking system requirements..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        error_exit "Node.js is not installed. Please install Node.js 16 or higher"
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        error_exit "npm is not installed"
    fi
    
    # Check CrowdSec
    if ! command -v cscli &> /dev/null; then
        error_exit "CrowdSec is not installed"
    fi
    
    success_msg "All system requirements met"
}

# Get server IP address
get_ip_address() {
    info_msg "Detecting IP address..."
    
    # Try different methods to get IP
    IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)
    
    if [ -z "$IP" ]; then
        IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -z "$IP" ]; then
        warning_msg "Could not automatically detect IP address"
        read -p "Please enter your server's IP address: " IP
        if [ -z "$IP" ]; then
            error_exit "IP address is required"
        fi
    fi
    
    success_msg "IP address detected: $IP"
    return 0
}

# Setup environment variables
setup_env() {
    info_msg "Setting up environment variables..."
    
    if [ -f .env ]; then
        warning_msg "Existing .env file found. Creating backup..."
        cp .env .env.backup
    fi
    
    cat > .env << EOL
PORT=3456
HOST=${IP}
NODE_ENV=production
EOL
    
    success_msg "Environment variables configured"
    info_msg "You can edit these settings in the future at: $(pwd)/.env"
}

# Install dependencies
install_dependencies() {
    info_msg "Installing Node.js dependencies..."
    
    npm install --production || error_exit "Failed to install dependencies"
    
    success_msg "Dependencies installed successfully"
}

# Setup systemd service
setup_service() {
    info_msg "Setting up systemd service..."
    
    # Create user and group if they don't exist
    if ! id -u crowdsec-dashboard &>/dev/null; then
        useradd -r -s /bin/false crowdsec-dashboard || error_exit "Failed to create service user"
    fi
    
    # Set correct permissions
    chown -R crowdsec-dashboard:crowdsec-dashboard . || error_exit "Failed to set permissions"
    
    # Copy and enable service
    cp crowdsec-metrics.service /etc/systemd/system/ || error_exit "Failed to copy service file"
    systemctl daemon-reload || error_exit "Failed to reload systemd"
    systemctl enable crowdsec-metrics || error_exit "Failed to enable service"
    systemctl start crowdsec-metrics || error_exit "Failed to start service"
    
    success_msg "Service installed and started"
}

# Main installation process
main() {
    print_banner
    
    echo "Starting installation..."
    echo "------------------------"
    
    check_sudo
    check_requirements
    get_ip_address
    setup_env
    install_dependencies
    setup_service
    
    echo -e "\n${GREEN}${BOLD}Installation Complete!${NC}"
    echo -e "${BLUE}------------------------${NC}"
    echo -e "Dashboard URL: ${BOLD}http://${IP}:3456${NC}"
    echo -e "Service status: ${BOLD}systemctl status crowdsec-metrics${NC}"
    echo -e "View logs: ${BOLD}journalctl -u crowdsec-metrics${NC}"
    echo -e "Configuration file: ${BOLD}$(pwd)/.env${NC}"
    echo -e "${BLUE}------------------------${NC}"
}

# Trap errors
trap 'error_exit "An error occurred during installation. Check the output above for details."' ERR

# Run main installation
main
