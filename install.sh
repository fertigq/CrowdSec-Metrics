#!/usr/bin/env bash

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Installation directory
INSTALL_DIR=$(pwd)

# ASCII art banner
print_banner() {
    echo -e "${BLUE}"
    echo "  ____                     _ ____             __  __      _        _          "
    echo " / ___|_ __ _____      __| / ___|  ___  ___ |  \/  | ___| |_ _ __(_) ___ ___"
    echo " | |   | '__/ _ \\ \\ /\\ / /| \\___\\ / _ \\/ __|| |\\/| |/ _ \\ __| '__| |/ __/ __|"
    echo " | |___| | | (_) \\ V  V / | |___) |  __/ (__ | |  | |  __/ |_| |  | | (__\\__ \\"
    echo "  \\____|_|  \\___/ \\_/\\_/  |_|____/ \\___|\\___||_|  |_|\\___|\\__|_|  |_|\\___|___/"
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

# Install Node.js and npm if not present
install_nodejs() {
    info_msg "Checking Node.js installation..."
    
    if ! command -v node &> /dev/null; then
        info_msg "Node.js not found. Installing Node.js 16.x..."
        
        # Add NodeSource repository
        curl -fsSL https://deb.nodesource.com/setup_16.x | bash - || error_exit "Failed to add Node.js repository"
        apt-get install -y nodejs || error_exit "Failed to install Node.js"
        
        success_msg "Node.js installed successfully"
    else
        success_msg "Node.js is already installed"
    fi
    
    if ! command -v npm &> /dev/null; then
        info_msg "Installing npm..."
        apt-get install -y npm || error_exit "Failed to install npm"
        success_msg "npm installed successfully"
    else
        success_msg "npm is already installed"
    fi
}

# Check system requirements
check_requirements() {
    info_msg "Checking system requirements..."
    
    # Check CrowdSec
    if ! command -v cscli &> /dev/null; then
        error_exit "CrowdSec is not installed. Please install CrowdSec first"
    fi
    
    success_msg "All system requirements met"
}

# Get server IP address and port
get_network_config() {
    info_msg "Detecting IP address..."
    
    # Try different methods to get IP
    DETECTED_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)
    
    if [ -z "$DETECTED_IP" ]; then
        DETECTED_IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -n "$DETECTED_IP" ]; then
        echo -e "Detected IP address: ${BOLD}${DETECTED_IP}${NC}"
        read -p "Would you like to use this IP address? [Y/n] " USE_DETECTED_IP
        USE_DETECTED_IP=${USE_DETECTED_IP:-Y}
        
        if [[ $USE_DETECTED_IP =~ ^[Yy]$ ]]; then
            IP=$DETECTED_IP
        fi
    fi
    
    if [ -z "$IP" ]; then
        read -p "Please enter your server's IP address: " IP
        if [ -z "$IP" ]; then
            error_exit "IP address is required"
        fi
    fi
    
    # Get port number
    read -p "Enter the port number for the dashboard [3456]: " PORT
    PORT=${PORT:-3456}
    
    # Validate port number
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        error_exit "Invalid port number. Please use a number between 1 and 65535"
    fi
    
    success_msg "Network configuration complete"
    echo -e "Using IP: ${BOLD}${IP}${NC}"
    echo -e "Using Port: ${BOLD}${PORT}${NC}"
}

# Setup environment variables
setup_env() {
    info_msg "Setting up environment variables..."
    
    if [ -f .env ]; then
        warning_msg "Existing .env file found. Creating backup..."
        cp .env .env.backup
    fi
    
    cat > .env << EOL
PORT=${PORT}
HOST=${IP}
NODE_ENV=production
EOL
    
    success_msg "Environment variables configured"
    info_msg "You can edit these settings in the future at: ${BOLD}${INSTALL_DIR}/.env${NC}"
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

# Print installation summary
print_summary() {
    echo -e "\n${GREEN}${BOLD}Installation Complete!${NC}"
    echo -e "${BLUE}------------------------${NC}"
    echo -e "Installation Directory: ${BOLD}${INSTALL_DIR}${NC}"
    echo -e "Dashboard URL: ${BOLD}http://${IP}:${PORT}${NC}"
    echo -e "Configuration file: ${BOLD}${INSTALL_DIR}/.env${NC}"
    echo -e "\nUseful commands:"
    echo -e "  View service status: ${BOLD}systemctl status crowdsec-metrics${NC}"
    echo -e "  View logs: ${BOLD}journalctl -u crowdsec-metrics${NC}"
    echo -e "  Edit configuration: ${BOLD}nano ${INSTALL_DIR}/.env${NC}"
    echo -e "${BLUE}------------------------${NC}"
}

# Main installation process
main() {
    print_banner
    
    echo "Starting installation..."
    echo "------------------------"
    
    check_sudo
    install_nodejs
    check_requirements
    get_network_config
    setup_env
    install_dependencies
    setup_service
    print_summary
}

# Trap errors
trap 'error_exit "An error occurred during installation. Check the output above for details."' ERR

# Run main installation
main
