#!/bin/bash

# Improved error handling and logging
set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Capture errors in pipe chains

# Logging
exec > >(tee /var/log/crowdsec-metrics-install.log) 2>&1

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/opt/crowdsec-metrics"

# Function to print colored messages
print_message() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to check if a command was successful
check_success() {
    local status=$?
    if [ $status -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2 (Exit status: $status)"
        exit 1
    fi
}

# Trap to catch any unexpected errors
trap 'print_error "An unexpected error occurred. Check /var/log/crowdsec-metrics-install.log for details."' ERR

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root or with sudo"
    exit 1
fi

# Print banner
echo "CrowdSec Metrics Dashboard Installer"
echo "------------------------"

# Ensure clean installation
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Removing existing installation directory"
    rm -rf "$INSTALL_DIR"
fi

# Create installation directory with explicit error handling
print_message "Creating installation directory..."
mkdir -p "$INSTALL_DIR" || { print_error "Failed to create installation directory"; exit 1; }
check_success "Installation directory created"

# Verify directory creation
[ -d "$INSTALL_DIR" ] || { print_error "Installation directory does not exist"; exit 1; }

# Copy files with verbose output
print_message "Copying files..."
cp -v server.js package.json "$INSTALL_DIR"/ || { print_error "Failed to copy server files"; exit 1; }
mkdir -p "$INSTALL_DIR"/public
cp -v public/index.html "$INSTALL_DIR"/public/ || { print_error "Failed to copy public files"; exit 1; }
check_success "Files copied successfully"

# Create .env file with more robust method
print_message "Creating .env file..."
cat > "$INSTALL_DIR"/.env << EOL
PORT=3456
HOST=0.0.0.0
NODE_ENV=production
VERBOSE_LOGGING=true
EOL
check_success ".env file created"

# Install dependencies with verbose npm output
print_message "Installing dependencies..."
cd "$INSTALL_DIR"
npm install --production --loglevel verbose
check_success "Dependencies installed successfully"

# Create user with additional checks
print_message "Creating user and setting permissions..."
id crowdsec-dashboard &>/dev/null || useradd -r -s /bin/false crowdsec-dashboard
chown -R crowdsec-dashboard:crowdsec-dashboard "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
check_success "User created and permissions set"

# Create systemd service with more robust error handling
print_message "Setting up systemd service..."
cat > /etc/systemd/system/crowdsec-metrics.service << EOL
[Unit]
Description=CrowdSec Metrics Dashboard
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/node $INSTALL_DIR/server.js
Restart=on-failure
RestartSec=10
User=crowdsec-dashboard
Group=crowdsec-dashboard
Environment=PATH=/usr/bin:/usr/local/bin
Environment=NODE_ENV=production
WorkingDirectory=$INSTALL_DIR
StandardOutput=journal
StandardError=journal
SyslogIdentifier=crowdsec-metrics

# Enhanced security
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOL
check_success "Systemd service file created"

# Reload, enable, and start service with error checking
systemctl daemon-reload
systemctl enable crowdsec-metrics
systemctl start crowdsec-metrics
check_success "Service enabled and started"

# Firewall configuration
print_message "Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 3456/tcp
    check_success "Firewall configured"
else
    print_warning "ufw not found. Please manually configure your firewall to allow traffic on port 3456."
fi

print_success "Installation complete!"
echo "------------------------"
echo "Installation Directory: $INSTALL_DIR"
echo "Dashboard URL: http://$(hostname -I | awk '{print $1}'):3456"
echo "Configuration file: $INSTALL_DIR/.env"
echo ""
echo "Useful commands:"
echo "  View service status: systemctl status crowdsec-metrics"
echo "  View logs: journalctl -u crowdsec-metrics"
echo "  Edit configuration: nano $INSTALL_DIR/.env"
echo "------------------------"
