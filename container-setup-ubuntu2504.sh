#!/usr/bin/env bash
set -euo pipefail

# Container Setup Script v3.0 - Ubuntu Server 25.04 Edition (Two-Phase)  
# Phase 2: Sets up Python 3.13.3, Node.js 20.18.1, optional Docker, and development tools
# Assumes dev user already exists (created in Phase 1)
# Uses native Ubuntu packages for faster, simpler installation

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
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
INSTALL_SSH="${INSTALL_SSH:-true}"
INSTALL_DOCKER="${INSTALL_DOCKER:-false}"
USER_PASSWORD="${USER_PASSWORD:-}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --user) SETUP_USER="$2"; shift 2 ;;
        --github-user) GITHUB_USERNAME="$2"; shift 2 ;;
        --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
        --user-password) USER_PASSWORD="$2"; shift 2 ;;
        --no-ssh) INSTALL_SSH="false"; shift ;;
        --docker) INSTALL_DOCKER="true"; shift ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --user NAME         User to create (default: dev)"
            echo "  --github-user NAME  GitHub username for SSH keys"
            echo "  --github-token PAT  GitHub Personal Access Token for gh CLI authentication"
            echo "  --user-password PWD Specific password for user (auto-generated if not provided)"
            echo "  --no-ssh           Skip SSH server installation"
            echo "  --docker           Install Docker CE and Docker Compose"
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

log_info "Starting Ubuntu Server 25.04 container setup..."

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

# Install Python 3.13.3 (native package in Ubuntu 25.04)
log_info "Installing Python 3.13.3..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev

# Verify Python version
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
log_info "Python installed: $PYTHON_VERSION"

# Verify user exists (should be created in Phase 1)
if ! id "$SETUP_USER" &>/dev/null; then
    log_error "User $SETUP_USER does not exist! This should have been created in Phase 1."
    log_error "Please run the proxmox-setup-ubuntu2504.sh script first."
    exit 1
fi

log_info "User $SETUP_USER exists - continuing with development environment setup"

# Ensure user has proper sudo access
usermod -aG sudo "$SETUP_USER" 2>/dev/null || true
echo "$SETUP_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$SETUP_USER"

# Use provided password or indicate existing user
if [ -n "$USER_PASSWORD" ]; then
    echo "$SETUP_USER:$USER_PASSWORD" | chpasswd
    echo "existing" > /tmp/user_password.txt
else
    echo "existing" > /tmp/user_password.txt
fi

# Set user home directory
USER_HOME="/home/$SETUP_USER"
if [ "$SETUP_USER" = "root" ]; then
    USER_HOME="/root"
fi

# Install Node.js 20.18.1 and npm via apt (Ubuntu 25.04 native packages)
if ! command -v node &>/dev/null; then
    log_info "Installing Node.js 20.18.1 and npm via apt..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm
else
    log_info "Node.js already installed, checking for updates..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade nodejs npm 2>/dev/null || true
fi

# Add locale settings to user's bashrc if not present
if ! grep -q "export LANG=en_US.UTF-8" "$USER_HOME/.bashrc"; then
    cat >> "$USER_HOME/.bashrc" << 'LOCALEEOF'

# Locale settings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
LOCALEEOF
fi

# Verify Node.js installation
NODE_VERSION=$(node --version 2>/dev/null || echo "not found")
NPM_VERSION=$(npm --version 2>/dev/null || echo "not found")
log_info "Node.js installed: $NODE_VERSION"
log_info "npm installed: $NPM_VERSION"

# Install Claude Code CLI if not already installed
if ! command -v claude &>/dev/null; then
    log_info "Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
else
    log_info "Claude Code CLI already installed, checking for updates..."
    npm update -g @anthropic-ai/claude-code
fi

log_info "Claude Code CLI installed/updated"

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

# Verify SSH setup (already configured in Phase 1)
if [ "$INSTALL_SSH" = "true" ]; then
    log_info "SSH server and dev user access already configured in Phase 1"
    
    # Add additional GitHub SSH keys if username provided and not already added
    if [ -n "$GITHUB_USERNAME" ]; then
        log_info "Checking for additional SSH keys from GitHub user: $GITHUB_USERNAME"
        GITHUB_KEYS=$(curl -fsSL "https://github.com/${GITHUB_USERNAME}.keys" 2>/dev/null || true)
        if [ -n "$GITHUB_KEYS" ]; then
            # Check if keys are already present to avoid duplicates
            while IFS= read -r key; do
                if ! grep -qF "$key" "$USER_HOME/.ssh/authorized_keys" 2>/dev/null; then
                    echo "$key" >> "$USER_HOME/.ssh/authorized_keys"
                    log_info "Added new SSH key from GitHub"
                fi
            done <<< "$GITHUB_KEYS"
            # Fix ownership
            chown -R "$SETUP_USER:$SETUP_USER" "$USER_HOME/.ssh"
        fi
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

# Install atuin (shell history tool) if not already installed
if [ ! -f "$USER_HOME/.local/bin/atuin" ]; then
    log_info "Installing atuin..."
    sudo -u "$SETUP_USER" bash -c "curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh"
else
    log_info "atuin already installed"
fi

# Make atuin available in user's shell if not already configured
if ! grep -q "atuin init bash" "$USER_HOME/.bashrc" 2>/dev/null; then
    cat >> "$USER_HOME/.bashrc" << 'ATUINEOF'

# atuin configuration
if command -v atuin &> /dev/null; then
    eval "$(atuin init bash)"
fi
ATUINEOF
    chown "$SETUP_USER:$SETUP_USER" "$USER_HOME/.bashrc"
    log_info "atuin shell integration added to .bashrc"
fi

log_info "atuin installed/configured"

# Install GitHub CLI if not already installed
if ! command -v gh &>/dev/null; then
    log_info "Installing GitHub CLI..."
    # Add GitHub CLI repository
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y gh
else
    log_info "GitHub CLI already installed, checking for updates..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade gh 2>/dev/null || true
fi

# Configure GitHub CLI authentication if token provided
if [ -n "$GITHUB_TOKEN" ]; then
    log_info "Configuring GitHub CLI authentication..."
    
    # Validate token format (GitHub PATs start with ghp_, gho_, ghu_, ghs_, ghr_, or are 40-char classic tokens)
    if [[ ! "$GITHUB_TOKEN" =~ ^(ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9_]{36}$ ]] && [[ ! "$GITHUB_TOKEN" =~ ^[a-f0-9]{40}$ ]]; then
        log_warn "GitHub token format appears invalid. Expected: ghp_xxxx... or 40-character hex string"
        log_warn "Authentication may fail. Proceeding anyway..."
    fi
    
    # Attempt authentication
    if echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/tmp/gh_auth_error.log; then
        log_info "GitHub CLI token accepted"
        
        # Verify authentication works
        if gh auth status >/dev/null 2>&1; then
            # Get the authenticated user for display
            GH_USER=$(gh api user --jq .login 2>/dev/null || echo "authenticated")
            log_info "GitHub CLI authenticated successfully as: $GH_USER"
            
            # Test API access
            if gh api user >/dev/null 2>&1; then
                log_info "GitHub API access verified"
            else
                log_warn "GitHub authentication succeeded but API access failed"
                log_warn "Token may have insufficient scopes"
            fi
        else
            log_warn "GitHub CLI login succeeded but authentication status check failed"
            if [ -f /tmp/gh_auth_error.log ]; then
                log_warn "Error details: $(cat /tmp/gh_auth_error.log | head -3)"
            fi
        fi
    else
        log_error "GitHub CLI authentication failed"
        if [ -f /tmp/gh_auth_error.log ]; then
            log_error "Error details: $(cat /tmp/gh_auth_error.log | head -3)"
        fi
        log_error "Common issues:"
        log_error "  - Invalid token format or expired token"
        log_error "  - Token missing required scopes (need: repo, read:org)"
        log_error "  - Network connectivity issues"
        log_warn "Continuing without GitHub CLI authentication"
    fi
    
    # Cleanup
    rm -f /tmp/gh_auth_error.log
else
    log_info "GitHub CLI installed but not authenticated"
    log_info "To authenticate, run setup with --github-token or set GITHUB_TOKEN environment variable"
    log_info "Create a token at: https://github.com/settings/tokens with 'repo' and 'read:org' scopes"
fi

# Install Docker CE and Docker Compose if requested
if [ "$INSTALL_DOCKER" = "true" ]; then
    log_info "Installing Docker CE and Docker Compose..."
    
    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        log_info "Docker is already installed, checking for updates..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    else
        # Install prerequisites for Docker repository
        log_info "Installing Docker prerequisites..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        log_info "Adding Docker repository..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Update package index
        apt-get update
        
        # Install Docker packages including Docker Compose v2 plugin
        log_info "Installing Docker CE, CLI, containerd, and Docker Compose plugin..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin
        
        # Enable and start Docker service
        systemctl enable docker
        systemctl start docker
    fi
    
    # Add user to docker group if not already a member
    if ! groups "$SETUP_USER" | grep -q docker; then
        log_info "Adding $SETUP_USER to docker group..."
        usermod -aG docker "$SETUP_USER"
        log_info "User $SETUP_USER added to docker group (logout required to take effect)"
    else
        log_info "User $SETUP_USER already in docker group"
    fi
    
    # Verify Docker installation
    if docker --version &>/dev/null; then
        log_info "Docker installed successfully: $(docker --version | head -1)"
    else
        log_warn "Docker installation verification failed"
    fi
    
    # Verify Docker Compose plugin installation
    if docker compose version &>/dev/null; then
        log_info "Docker Compose installed successfully: $(docker compose version)"
    else
        log_warn "Docker Compose installation verification failed"
    fi
fi

# Clean up
log_info "Cleaning up..."
apt-get autoremove -y
apt-get autoclean

# Summary
echo ""
echo "========================================="
echo "Ubuntu Server 25.04 Container Setup Complete!"
echo "========================================="
echo "Python: $(python3 --version)"
echo "Node.js: $(node --version 2>/dev/null || echo "not found")"
echo "npm: $(npm --version 2>/dev/null || echo "not found")"
echo "Claude Code: $(claude --version 2>/dev/null || echo "installed")"
echo "uv: $(sudo -u "$SETUP_USER" bash -c 'source ~/.bashrc && uv --version' 2>/dev/null || echo "installed")"
echo "atuin: $(sudo -u "$SETUP_USER" bash -c '. ~/.bashrc && atuin --version 2>/dev/null' || echo "installed")"
echo "GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo "installed")"
if [ -n "$GITHUB_TOKEN" ] && gh auth status &>/dev/null; then
    echo "GitHub CLI Auth: Configured"
fi
if [ "$INSTALL_DOCKER" = "true" ]; then
    echo "Docker: $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo "installed")"
    echo "Docker Compose: $(docker compose version 2>/dev/null | awk '{print $4}' || echo "installed")"
fi
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