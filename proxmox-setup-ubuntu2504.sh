#!/usr/bin/env bash
set -euo pipefail

# Proxmox CT Setup Script v3.0 - Ubuntu Server 25.04 Edition (Two-Phase)
# Phase 1: Creates Ubuntu Server 25.04 container with dev user and SSH keys
# Phase 2: Manual setup via SSH - installs development tools and applications

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
CTID="${CTID:-}"
CT_NAME="${CT_NAME:-ubuntu2504-devbox-$(date +%y%m%d)}"
CT_MEMORY="${CT_MEMORY:-4096}"
CT_CORES="${CT_CORES:-2}"
CT_DISK="${CT_DISK:-20}"
CT_STORAGE="${CT_STORAGE:-local-zfs}"
CT_PASSWORD="${CT_PASSWORD:-$(openssl rand -base64 12)}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
GITHUB_USERNAME="${GITHUB_USERNAME:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
UBUNTU_VERSION="${UBUNTU_VERSION:-25.04}"
START_AFTER_CREATE="${START_AFTER_CREATE:-true}"
FORCE_RECREATE="${FORCE_RECREATE:-false}"
INSTALL_DOCKER="${INSTALL_DOCKER:-false}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ctid) CTID="$2"; shift 2 ;;
        --name) CT_NAME="$2"; shift 2 ;;
        --memory) CT_MEMORY="$2"; shift 2 ;;
        --cores) CT_CORES="$2"; shift 2 ;;
        --disk) CT_DISK="$2"; shift 2 ;;
        --storage) CT_STORAGE="$2"; shift 2 ;;
        --github-user) GITHUB_USERNAME="$2"; shift 2 ;;
        --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
        --docker) INSTALL_DOCKER="true"; shift ;;
        --force) FORCE_RECREATE="true"; shift ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --ctid ID           Container ID (auto-detect if not specified)"
            echo "  --name NAME         Container name (default: ubuntu2504-devbox-YYMMDD)"
            echo "  --memory MB         Memory in MB (default: 4096)"
            echo "  --cores N           CPU cores (default: 2)"
            echo "  --disk GB           Disk size in GB (default: 20)"
            echo "  --storage NAME      Storage pool (default: local-zfs)"
            echo "  --github-user NAME  GitHub username for SSH keys"
            echo "  --github-token PAT  GitHub Personal Access Token for gh CLI authentication"
            echo "  --docker            Install Docker CE and Docker Compose"
            echo "  --force             Force recreate if container exists"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# Check if running on Proxmox
if ! command -v pct &>/dev/null; then
    log_error "This script must be run on a Proxmox host"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check if container with same name already exists
EXISTING_CTID=""
for id in $(pct list | tail -n +2 | awk '{print $1}'); do
    EXISTING_NAME=$(pct config $id | grep "^hostname:" | cut -d' ' -f2)
    if [ "$EXISTING_NAME" = "$CT_NAME" ]; then
        EXISTING_CTID=$id
        break
    fi
done

# Handle existing container
if [ -n "$EXISTING_CTID" ]; then
    if [ "$FORCE_RECREATE" = "true" ]; then
        log_warn "Container '$CT_NAME' (ID: $EXISTING_CTID) exists. Force recreating..."
        
        # Stop and destroy existing container
        pct stop $EXISTING_CTID 2>/dev/null || true
        sleep 2
        pct destroy $EXISTING_CTID --force
        
        # Use the same CTID if not specified
        if [ -z "$CTID" ]; then
            CTID=$EXISTING_CTID
        fi
    else
        log_error "Container '$CT_NAME' already exists (ID: $EXISTING_CTID)"
        log_info "Use --force to recreate it"
        exit 1
    fi
fi

# Find next available CTID if not specified
if [ -z "$CTID" ]; then
    for id in $(seq 100 999); do
        if ! pct status $id &>/dev/null 2>&1; then
            CTID=$id
            break
        fi
    done
    if [ -z "$CTID" ]; then
        log_error "No available CTID found"
        exit 1
    fi
fi

# Final check if CTID is available
if pct status $CTID &>/dev/null 2>&1; then
    log_error "Container $CTID already exists"
    exit 1
fi

log_info "Proxmox CT Setup Script v3.0 - Ubuntu Server 25.04 Edition (Two-Phase)"
log_info "Configuration:"
log_info "  CTID: $CTID"
log_info "  Name: $CT_NAME"
log_info "  Memory: ${CT_MEMORY}MB"
log_info "  Cores: $CT_CORES"
log_info "  Disk: ${CT_DISK}GB"
log_info "  Storage: $CT_STORAGE"
log_info "  Network: DHCP (vmbr0)"
if [ -n "$GITHUB_USERNAME" ]; then
    log_info "  GitHub User: $GITHUB_USERNAME (for SSH keys)"
fi
if [ "$INSTALL_DOCKER" = "true" ]; then
    log_info "  Docker: Will be installed with Docker Compose"
fi

# Download Ubuntu template if not exists
log_info "Updating template list..."
pveam update

log_info "Checking for Ubuntu 25.04 templates..."

# First, let's see ALL available templates to understand the format
log_info "Fetching available templates..."
ALL_TEMPLATES=$(pveam available)

# Debug: show what Ubuntu templates are available
UBUNTU_TEMPLATES=$(echo "$ALL_TEMPLATES" | grep -i ubuntu || true)
if [ -n "$UBUNTU_TEMPLATES" ]; then
    log_info "Available Ubuntu templates (first 5):"
    echo "$UBUNTU_TEMPLATES" | head -5
fi

# Now look specifically for Ubuntu 25.04
AVAILABLE_TEMPLATES=$(echo "$ALL_TEMPLATES" | grep -i "ubuntu-25.04" || true)

if [ -z "$AVAILABLE_TEMPLATES" ]; then
    log_error "Ubuntu 25.04 template not found in Proxmox repository"
    log_error "Please ensure your Proxmox repositories are configured correctly"
    exit 1
fi

# The output format is: <repository> <template-name>
# We need just the template name (second column)
TEMPLATE_NAME=$(echo "$AVAILABLE_TEMPLATES" | head -1 | awk '{print $2}')

if [ -z "$TEMPLATE_NAME" ]; then
    log_error "Could not parse Ubuntu 25.04 template name"
    log_info "Raw output: $AVAILABLE_TEMPLATES"
    exit 1
fi

log_info "Found template: $TEMPLATE_NAME"

TEMPLATE_PATH="/var/lib/vz/template/cache/${TEMPLATE_NAME}"

if [ ! -f "$TEMPLATE_PATH" ]; then
    log_info "Downloading template: $TEMPLATE_NAME"
    pveam download local "$TEMPLATE_NAME"
else
    log_info "Using existing template: $TEMPLATE_NAME"
fi

# Create container
log_info "Creating Ubuntu $UBUNTU_VERSION container..."
pct create $CTID "$TEMPLATE_PATH" \
    --hostname "$CT_NAME" \
    --memory "$CT_MEMORY" \
    --cores "$CT_CORES" \
    --rootfs "${CT_STORAGE}:${CT_DISK}" \
    --net0 "name=eth0,bridge=vmbr0,ip=dhcp,firewall=1" \
    --password "$CT_PASSWORD" \
    --unprivileged 1 \
    --features "nesting=1" \
    --ostype ubuntu

# Start container
log_info "Starting container..."
pct start $CTID

# Wait for container to be ready
log_info "Waiting for container to be ready..."
sleep 5

# Get container IP (wait for DHCP)
log_info "Waiting for IP address..."
for i in {1..30}; do
    CONTAINER_IP=$(pct exec $CTID -- ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)
    if [ -n "$CONTAINER_IP" ]; then
        break
    fi
    sleep 2
done

# Install essential packages for Phase 1 (SSH access + curl for Phase 2)
log_info "Installing SSH server and curl for access..."
pct exec $CTID -- bash -c "apt update && apt install -y openssh-server curl"

# Generate dev user password for display (same method as container-setup script)
DEV_PASSWORD=$(openssl rand -base64 12)

# Create dev user and setup SSH access (Phase 1)
log_info "Creating dev user and configuring SSH..."
pct exec $CTID -- bash -c "
    # Create dev user with sudo access
    if ! id dev &>/dev/null; then
        useradd -m -s /bin/bash -G sudo dev
        echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev
        echo 'dev:$DEV_PASSWORD' | chpasswd
    fi
    
    # Configure SSH for dev user access (no root login)
    sed -i 's/#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # Setup SSH directory for dev user
    mkdir -p /home/dev/.ssh
    touch /home/dev/.ssh/authorized_keys
    chmod 700 /home/dev/.ssh
    chmod 600 /home/dev/.ssh/authorized_keys
    chown -R dev:dev /home/dev/.ssh
    
    # Start and enable SSH service
    systemctl start ssh
    systemctl enable ssh
"

# Add GitHub SSH keys if username provided
if [ -n "$GITHUB_USERNAME" ]; then
    log_info "Fetching SSH keys from GitHub user: $GITHUB_USERNAME"
    GITHUB_KEYS=$(curl -fsSL "https://github.com/${GITHUB_USERNAME}.keys" 2>/dev/null || true)
    if [ -n "$GITHUB_KEYS" ]; then
        # Add keys to dev user's authorized_keys
        pct exec $CTID -- bash -c "
            while IFS= read -r key; do
                if ! grep -qF \"\$key\" /home/dev/.ssh/authorized_keys 2>/dev/null; then
                    echo \"\$key\" >> /home/dev/.ssh/authorized_keys
                fi
            done <<< '$GITHUB_KEYS'
            chown -R dev:dev /home/dev/.ssh
        "
        log_info "GitHub SSH keys added for $GITHUB_USERNAME"
    else
        log_warn "Could not fetch SSH keys from GitHub"
    fi
fi

# Build setup command with arguments for display
SETUP_ARGS="--user dev --user-password $DEV_PASSWORD"
if [ -n "$GITHUB_USERNAME" ]; then
    SETUP_ARGS="$SETUP_ARGS --github-user $GITHUB_USERNAME"
fi
if [ "$INSTALL_DOCKER" = "true" ]; then
    SETUP_ARGS="$SETUP_ARGS --docker"
fi
if [ -n "$GITHUB_TOKEN" ]; then
    SETUP_ARGS="$SETUP_ARGS --github-token <YOUR_GITHUB_TOKEN>"
fi

# Final message
log_info "========================================="
log_info "Container created successfully!"
log_info "========================================="
log_info "Container ID: $CTID"
log_info "Container Name: $CT_NAME"
if [ -n "$CONTAINER_IP" ]; then
    log_info "IP Address: $CONTAINER_IP"
fi
log_info ""
log_info "Root password: $CT_PASSWORD"
log_info "Dev password: $DEV_PASSWORD"
log_info ""
log_info "IMPORTANT: Save these passwords securely!"
log_info ""
log_info "========================================="
log_info "NEXT STEPS:"
log_info "========================================="
log_info "1. SSH into the container as dev user:"
log_info "   ssh dev@${CONTAINER_IP:-<CONTAINER_IP>}"
if [ -n "$GITHUB_USERNAME" ]; then
    log_info "   (SSH keys from GitHub user '$GITHUB_USERNAME' are configured)"
else
    log_info "   (Use the dev password shown above)"
fi
log_info ""
log_info "2. Run the setup script:"
if [ -n "$GITHUB_TOKEN" ]; then
    # Don't show token in args, use environment variable approach
    DISPLAY_ARGS=$(echo "$SETUP_ARGS" | sed "s/ --github-token <YOUR_GITHUB_TOKEN>//")
    log_info "   GITHUB_TOKEN='[your_token_here]' \\"
    log_info "   curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup-ubuntu2504.sh | bash -s -- $DISPLAY_ARGS"
    log_info ""
    log_info "   OR with token as parameter:"
    log_info "   curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup-ubuntu2504.sh | bash -s -- $DISPLAY_ARGS --github-token '$GITHUB_TOKEN'"
else
    log_info "   curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup-ubuntu2504.sh | bash -s -- $SETUP_ARGS"
fi
log_info ""
log_info "This will install Python 3.13.3, Node.js 20.18.1, Claude Code CLI, GitHub CLI,"
log_info "and uv package manager in the existing 'dev' user environment."
if [ "$INSTALL_DOCKER" = "true" ]; then
    log_info "Docker CE and Docker Compose v2 will also be installed."
fi
if [ -n "$GITHUB_USERNAME" ]; then
    log_info "SSH keys fetched from GitHub user: $GITHUB_USERNAME"
fi
if [ -n "$GITHUB_TOKEN" ]; then
    log_info "GitHub CLI will be authenticated with your token."
fi
log_info ""
log_info "SECURITY NOTE: Container is configured with secure 'dev' user access."
log_info "Root SSH login is disabled for security. Phase 2 installs development tools."
log_info "========================================="