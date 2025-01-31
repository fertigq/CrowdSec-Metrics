#!/bin/bash
set -euo pipefail

# Configuration
APP_NAME="crowdsec-metrics"
INSTALL_DIR="/opt/${APP_NAME}"
SERVICE_USER="crowdsec-dashboard"
REQUIRED_FILES=("install.sh" "crowdsec-metrics.service" "package.json" ".env.example")

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error handling
trap 'cleanup && echo -e "${RED}Installation aborted!${NC}" >&2 && exit 1' ERR

cleanup() {
    # Remove partial installation on failure
    if [[ -d "${INSTALL_DIR}" && "$(ls -A ${INSTALL_DIR})" ]]; then
        echo -e "${YELLOW}Cleaning up partial installation...${NC}"
        rm -rf "${INSTALL_DIR}/"*
    fi
}

# Pre-install checks
verify_environment() {
    # Check if running as root
    [[ $EUID -eq 0 ]] || { echo -e "${RED}Must be run as root${NC}" >&2; exit 1; }

    # Verify script location contains required files
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "${script_dir}/${file}" ]]; then
            echo -e "${RED}Missing required file: ${file}${NC}" >&2
            echo -e "Place all installation files in the same directory as this script"
            exit 1
        fi
    done

    # Prevent running from target directory
    if [[ "${script_dir}" == "${INSTALL_DIR}" ]]; then
        echo -e "${RED}Do NOT run this script from ${INSTALL_DIR}${NC}" >&2
        echo -e "Create a separate directory with all required files and run from there"
        exit 1
    fi
}

install_dependencies() {
    # Install Node.js if needed
    if ! command -v npm &> /dev/null; then
        echo -e "${YELLOW}Installing Node.js...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi

    # Verify npm exists
    command -v npm &> /dev/null || { 
        echo -e "${RED}Failed to install Node.js/npm${NC}" >&2
        exit 1
    }
}

setup_application() {
    # Create service user
    if ! id "${SERVICE_USER}" &> /dev/null; then
        useradd -r -s /bin/false "${SERVICE_USER}"
        usermod -aG docker "${SERVICE_USER}" 2>/dev/null || true
    fi

    # Create install directory
    mkdir -p "${INSTALL_DIR}"
    chown "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_DIR}"

    # Copy application files
    echo -e "${YELLOW}Copying application files...${NC}"
    rsync -av --exclude=.env --exclude=node_modules/ \
        "$(dirname "${BASH_SOURCE[0]}")/" "${INSTALL_DIR}/"

    # Install npm dependencies
    echo -e "${YELLOW}Installing dependencies...${NC}"
    sudo -u "${SERVICE_USER}" npm install --prefix "${INSTALL_DIR}" --production

    # Create .env file
    if [[ ! -f "${INSTALL_DIR}/.env" ]]; then
        cp "${INSTALL_DIR}/.env.example" "${INSTALL_DIR}/.env"
        chown "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_DIR}/.env"
        chmod 600 "${INSTALL_DIR}/.env"
    fi
}

configure_system() {
    # Sudoers configuration
    local sudoers_file="/etc/sudoers.d/${SERVICE_USER}"
    if [[ ! -f "${sudoers_file}" ]]; then
        echo "${SERVICE_USER} ALL=(ALL) NOPASSWD: /usr/bin/cscli metrics" > "${sudoers_file}"
        echo "${SERVICE_USER} ALL=(root) NOPASSWD: /usr/bin/docker exec crowdsec cscli metrics" >> "${sudoers_file}"
        chmod 440 "${sudoers_file}"
    fi

    # Systemd service
    local service_file="/etc/systemd/system/${APP_NAME}.service"
    if [[ ! -f "${service_file}" ]]; then
        cp "${INSTALL_DIR}/crowdsec-metrics.service" "${service_file}"
        systemctl daemon-reload
    fi

    # Enable and start service
    systemctl enable --now "${APP_NAME}" || true
}

post_install() {
    # Set permissions
    chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_DIR}"
    find "${INSTALL_DIR}" -type d -exec chmod 750 {} \;
    find "${INSTALL_DIR}" -type f -exec chmod 640 {} \;

    # Firewall configuration
    if command -v ufw &> /dev/null && ! ufw status | grep -q 3456/tcp; then
        ufw allow 3456/tcp
    fi

    echo -e "\n${GREEN}Installation complete!${NC}"
    echo -e "Next steps:"
    echo -e "1. Edit configuration: ${YELLOW}nano ${INSTALL_DIR}/.env${NC}"
    echo -e "2. Restart service:    ${YELLOW}systemctl restart ${APP_NAME}${NC}"
}

# Main execution flow
verify_environment
install_dependencies
setup_application
configure_system
post_install
