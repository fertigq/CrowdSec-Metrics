#!/bin/bash

# Stop and disable the service
sudo systemctl stop crowdsec-metrics
sudo systemctl disable crowdsec-metrics

# Remove the service file
sudo rm /etc/systemd/system/crowdsec-metrics.service

# Reload systemd
sudo systemctl daemon-reload

# Remove the installation directory
sudo rm -rf /opt/crowdsec-metrics

# Remove the user and group
sudo userdel crowdsec-dashboard

# Remove firewall rule (adjust if necessary)
sudo ufw delete allow 3456

echo "CrowdSec Metrics Dashboard has been uninstalled."
