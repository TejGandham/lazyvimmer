#!/usr/bin/env bash
set -euo pipefail

# Container Setup Script
# Sets up Python 3.12, Node.js LTS, and development tools
# Can be run inside any Ubuntu 24.04 container or VM

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SETUP_USER="${SETUP_USER:-dev}"
GITHUB_USERNAME="${GITHUB_USERNAME:-}"
INSTALL_SSH="${INSTALL_SSH:-true}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --user) SETUP_USER="$2"; shift 2 ;;
        --github-user) GITHUB_USERNAME="$2"; shift 2 ;;
        --no-ssh) INSTALL_SSH="false"; shift ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --user NAME        User to create (default: dev)"
            echo "  --github-user NAME GitHub username for SSH keys"
            echo "  --no-ssh          Skip SSH server installation"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

log_info "Starting container setup..."

# Update system
log_info "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install essential packages
log_info "Installing essential packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    sudo \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    tar \
    gzip \
    locales

# Configure locale settings
log_info "Configuring locale settings..."
# Generate en_US.UTF-8 locale if not exists
if ! locale -a | grep -q "en_US.utf8"; then
    locale-gen en_US.UTF-8
fi
# Set default locale
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
# Export for current session
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Install Python 3.12
log_info "Installing Python 3.12..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev

# Verify Python version
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
log_info "Python installed: $PYTHON_VERSION"

# Create user if it doesn't exist
if ! id "$SETUP_USER" &>/dev/null; then
    log_info "Creating user: $SETUP_USER"
    useradd -m -s /bin/bash -G sudo "$SETUP_USER"
    echo "$SETUP_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$SETUP_USER"
    
    # Generate random password
    USER_PASSWORD=$(openssl rand -base64 12)
    echo "$SETUP_USER:$USER_PASSWORD" | chpasswd
    
    # Save password for display later
    echo "$USER_PASSWORD" > /tmp/user_password.txt
    chmod 600 /tmp/user_password.txt
else
    log_info "User $SETUP_USER already exists"
    echo "existing" > /tmp/user_password.txt
    
    # Ensure user is in sudo group and has NOPASSWD access
    usermod -aG sudo "$SETUP_USER" 2>/dev/null || true
    echo "$SETUP_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$SETUP_USER"
fi

# Set user home directory
USER_HOME="/home/$SETUP_USER"
if [ "$SETUP_USER" = "root" ]; then
    USER_HOME="/root"
fi

# Install Node.js via nvm if not already installed
if [ ! -d "$USER_HOME/.nvm" ]; then
    log_info "Installing nvm and Node.js LTS..."
    
    # Download and install nvm
    NVM_VERSION="v0.40.3"
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | sudo -u "$SETUP_USER" bash
    
    # Source nvm and install Node.js LTS
    sudo -u "$SETUP_USER" bash -c "
        export NVM_DIR=\"$USER_HOME/.nvm\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
        nvm install --lts
        nvm use --lts
        nvm alias default lts/*
        node --version
        npm --version
    "
else
    log_info "nvm already installed, updating Node.js LTS..."
    sudo -u "$SETUP_USER" bash -c "
        export NVM_DIR=\"$USER_HOME/.nvm\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
        nvm install --lts
        nvm use --lts
        nvm alias default lts/*
        node --version
        npm --version
    "
fi

# Make nvm available in user's shell
if ! grep -q "NVM_DIR" "$USER_HOME/.bashrc"; then
    cat >> "$USER_HOME/.bashrc" << 'NVMEOF'

# NVM configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
NVMEOF
fi

# Add locale settings to user's bashrc if not present
if ! grep -q "export LANG=en_US.UTF-8" "$USER_HOME/.bashrc"; then
    cat >> "$USER_HOME/.bashrc" << 'LOCALEEOF'

# Locale settings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
LOCALEEOF
fi

log_info "Node.js LTS installed/updated via nvm"

# Install uv (Python package manager) if not already installed
if [ ! -f "$USER_HOME/.local/bin/uv" ]; then
    log_info "Installing uv..."
    sudo -u "$SETUP_USER" bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
else
    log_info "uv already installed, checking for updates..."
    sudo -u "$SETUP_USER" bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

# Make uv available in user's shell
if ! grep -q "uv" "$USER_HOME/.bashrc"; then
    cat >> "$USER_HOME/.bashrc" << 'UVEOF'

# uv configuration
export PATH="$HOME/.local/bin:$PATH"
UVEOF
fi

log_info "uv installed/updated"

# Setup SSH if requested
if [ "$INSTALL_SSH" = "true" ]; then
    log_info "Installing and configuring SSH server..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server
    
    # Configure SSH
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # Restart SSH service (Ubuntu uses 'ssh' not 'sshd')
    systemctl restart ssh
    systemctl enable ssh
    
    # Setup SSH directory for user
    USER_HOME="/home/$SETUP_USER"
    if [ "$SETUP_USER" = "root" ]; then
        USER_HOME="/root"
    fi
    
    mkdir -p "$USER_HOME/.ssh"
    touch "$USER_HOME/.ssh/authorized_keys"
    chmod 700 "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    
    # Add GitHub SSH keys if username provided
    if [ -n "$GITHUB_USERNAME" ]; then
        log_info "Fetching SSH keys from GitHub user: $GITHUB_USERNAME"
        GITHUB_KEYS=$(curl -fsSL "https://github.com/${GITHUB_USERNAME}.keys" 2>/dev/null || true)
        if [ -n "$GITHUB_KEYS" ]; then
            # Check if keys are already present to avoid duplicates
            while IFS= read -r key; do
                if ! grep -qF "$key" "$USER_HOME/.ssh/authorized_keys" 2>/dev/null; then
                    echo "$key" >> "$USER_HOME/.ssh/authorized_keys"
                fi
            done <<< "$GITHUB_KEYS"
            log_info "GitHub SSH keys synchronized for $GITHUB_USERNAME"
        else
            log_warn "Could not fetch SSH keys from GitHub"
        fi
    fi
    
    # Fix ownership
    if [ "$SETUP_USER" != "root" ]; then
        chown -R "$SETUP_USER:$SETUP_USER" "$USER_HOME/.ssh"
    fi
fi

# Install additional development tools
log_info "Installing additional development tools..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    vim \
    nano \
    htop \
    net-tools \
    iputils-ping \
    dnsutils

# Install GitHub CLI if not already installed
if ! command -v gh &>/dev/null; then
    log_info "Installing GitHub CLI..."
    (type -p wget >/dev/null || (apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install wget -y)) \
	&& mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install gh -y
else
    log_info "GitHub CLI already installed, checking for updates..."
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade gh -y 2>/dev/null || true
fi

# Clean up
log_info "Cleaning up..."
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

# Summary
echo ""
echo "========================================="
echo "Container Setup Complete!"
echo "========================================="
echo "Python: $(python3 --version)"
echo "Node.js: $(sudo -u "$SETUP_USER" bash -c 'source ~/.nvm/nvm.sh && node --version' 2>/dev/null || echo "via nvm")"
echo "npm: $(sudo -u "$SETUP_USER" bash -c 'source ~/.nvm/nvm.sh && npm --version' 2>/dev/null || echo "via nvm")"
echo "uv: $(sudo -u "$SETUP_USER" bash -c 'source ~/.bashrc && uv --version' 2>/dev/null || echo "installed")"
echo "GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo "installed")"
echo ""
echo "User: $SETUP_USER"

# Display password if user was created
if [ -f /tmp/user_password.txt ]; then
    USER_PASS_STATUS=$(cat /tmp/user_password.txt)
    if [ "$USER_PASS_STATUS" != "existing" ]; then
        echo "Password: $USER_PASS_STATUS"
        echo ""
        echo "IMPORTANT: Save this password securely!"
    fi
    rm -f /tmp/user_password.txt
fi

if [ "$INSTALL_SSH" = "true" ]; then
    echo "SSH: Enabled (port 22)"
    if [ -n "$GITHUB_USERNAME" ]; then
        echo "GitHub SSH keys: Added for $GITHUB_USERNAME"
    fi
fi
echo "========================================="