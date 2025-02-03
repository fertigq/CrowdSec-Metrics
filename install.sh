#!/bin/bash

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
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        exit 1
    fi
}

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root or with sudo"
    exit 1
fi

# Print banner
echo "
 ____                      _ ____             __  __      _        _          
/ ___|_ __ _____      ____| / ___|  ___  ___ |  \/  | ___| |_ _ __(_) ___ ___ 
| |   | '__/ _ \ \ /\ / / _\` \___ \ / _ \/ __|| |\/| |/ _ \ __| '__| |/ __/ __|
| |___| | | (_) \ V  V / (_| |___) |  __/ (__ | |  | |  __/ |_| |  | | (__\__ \\
\____|_|  \___/ \_/\_/ \__,_|____/ \___|\___||_|  |_|\___|\__|_|  |_|\___|___/
"
echo "Dashboard Installer"
echo "------------------------"

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    print_message "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
    apt-get install -y nodejs
    check_success "Node.js installed successfully" "Failed to install Node.js"
else
    print_success "Node.js is already installed"
fi

# Create installation directory
print_message "Creating installation directory..."
mkdir -p $INSTALL_DIR
check_success "Installation directory created" "Failed to create installation directory"

# Copy files
print_message "Copying files..."
cp server.js package.json $INSTALL_DIR/
mkdir -p $INSTALL_DIR/public
cp public/index.html $INSTALL_DIR/public/
check_success "Files copied successfully" "Failed to copy files"

# Create .env file
cat > $INSTALL_DIR/.env << EOL
PORT=3456
HOST=0.0.0.0
NODE_ENV=production
EOL
check_success ".env file created" "Failed to create .env file"

# Install dependencies
print_message "Installing dependencies..."
cd $INSTALL_DIR
npm install --production
check_success "Dependencies installed successfully" "Failed to install dependencies"

# Create user and set permissions
print_message "Creating user and setting permissions..."
useradd -r -s /bin/false crowdsec-dashboard
chown -R crowdsec-dashboard:crowdsec-dashboard $INSTALL_DIR
chmod -R 755 $INSTALL_DIR
check_success "User created and permissions set" "Failed to create user or set permissions"

# Add user to docker group
print_message "Adding user to docker group..."
usermod -aG docker crowdsec-dashboard
check_success "User added to docker group" "Failed to add user to docker group"

# Create and configure the service
print_message "Setting up systemd service..."
cat > /etc/systemd/system/crowdsec-metrics.service << EOL
[Unit]
Description=CrowdSec Metrics Dashboard
After=network.target

[Service]
ExecStart=/usr/bin/node $INSTALL_DIR/server.js
Restart=always
User=crowdsec-dashboard
Group=crowdsec-dashboard
Environment=PATH=/usr/bin:/usr/local/bin
Environment=NODE_ENV=production
WorkingDirectory=$INSTALL_DIR
StandardOutput=journal
StandardError=journal
SyslogIdentifier=crowdsec-metrics

# Security enhancements
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOL
check_success "Systemd service file created" "Failed to create systemd service file"

systemctl daemon-reload
systemctl enable crowdsec-metrics
systemctl start crowdsec-metrics
check_success "Service enabled and started" "Failed to enable or start service"

# Configure firewall
print_message "Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 3456/tcp
    check_success "Firewall configured" "Failed to configure firewall"
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
