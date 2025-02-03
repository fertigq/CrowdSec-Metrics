#!/bin/bash

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root or with sudo"
    exit 1
fi

# Stop and disable the service
print_message "Stopping and disabling service..."
systemctl stop crowdsec-metrics
systemctl disable crowdsec-metrics

# Remove the service file
print_message "Removing service file..."
rm /etc/systemd/system/crowdsec-metrics.service

# Reload systemd
systemctl daemon-reload

# Remove the installation directory
print_message "Removing installation directory..."
rm -rf /opt/crowdsec-metrics

# Remove the user
print_message "Removing user..."
userdel crowdsec-dashboard

# Remove firewall rule
print_message "Removing firewall rule..."
ufw delete allow 3456/tcp

print_success "CrowdSec Metrics Dashboard has been uninstalled."
