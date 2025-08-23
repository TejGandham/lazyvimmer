#!/usr/bin/env bash
set -euo pipefail

# Proxmox CT Setup Script v2.0
# Creates Ubuntu 24.04 LTS container with Python 3.12 and Node.js LTS

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
CT_NAME="${CT_NAME:-devbox-$(date +%y%m%d)}"
CT_MEMORY="${CT_MEMORY:-4096}"
CT_CORES="${CT_CORES:-2}"
CT_DISK="${CT_DISK:-20}"
CT_STORAGE="${CT_STORAGE:-local-zfs}"
CT_PASSWORD="${CT_PASSWORD:-$(openssl rand -base64 12)}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
GITHUB_USERNAME="${GITHUB_USERNAME:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
UBUNTU_VERSION="${UBUNTU_VERSION:-24.04}"
START_AFTER_CREATE="${START_AFTER_CREATE:-true}"
FORCE_RECREATE="${FORCE_RECREATE:-false}"

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
        --force) FORCE_RECREATE="true"; shift ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --ctid ID           Container ID (auto-detect if not specified)"
            echo "  --name NAME         Container name (default: devbox-YYMMDD)"
            echo "  --memory MB         Memory in MB (default: 4096)"
            echo "  --cores N           CPU cores (default: 2)"
            echo "  --disk GB           Disk size in GB (default: 20)"
            echo "  --storage NAME      Storage pool (default: local-zfs)"
            echo "  --github-user NAME  GitHub username for SSH keys"
            echo "  --github-token PAT  GitHub Personal Access Token for gh CLI authentication"
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

log_info "Proxmox CT Setup Script v2.0"
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

# Download Ubuntu template if not exists
log_info "Updating template list..."
pveam update

log_info "Checking for Ubuntu 24.04 templates..."

# First, let's see ALL available templates to understand the format
log_info "Fetching available templates..."
ALL_TEMPLATES=$(pveam available)

# Debug: show what Ubuntu templates are available
UBUNTU_TEMPLATES=$(echo "$ALL_TEMPLATES" | grep -i ubuntu || true)
if [ -n "$UBUNTU_TEMPLATES" ]; then
    log_info "Available Ubuntu templates (first 5):"
    echo "$UBUNTU_TEMPLATES" | head -5
fi

# Now look specifically for Ubuntu 24.04
AVAILABLE_TEMPLATES=$(echo "$ALL_TEMPLATES" | grep -i "ubuntu-24.04" || true)

if [ -z "$AVAILABLE_TEMPLATES" ]; then
    log_error "Ubuntu 24.04 template not found in Proxmox repository"
    log_error "Please ensure your Proxmox repositories are configured correctly"
    exit 1
fi

# The output format is: <repository> <template-name>
# We need just the template name (second column)
TEMPLATE_NAME=$(echo "$AVAILABLE_TEMPLATES" | head -1 | awk '{print $2}')

if [ -z "$TEMPLATE_NAME" ]; then
    log_error "Could not parse Ubuntu 24.04 template name"
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

# Get SSH keys from GitHub if username provided
SSH_KEYS=""
if [ -n "$GITHUB_USERNAME" ]; then
    log_info "Fetching SSH keys from GitHub user: $GITHUB_USERNAME"
    SSH_KEYS=$(curl -fsSL "https://github.com/${GITHUB_USERNAME}.keys" 2>/dev/null || true)
    if [ -z "$SSH_KEYS" ]; then
        log_warn "Could not fetch SSH keys from GitHub"
    fi
fi

# Download and run the full container setup script
log_info "Downloading container setup script..."
pct exec $CTID -- bash -c "curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh -o /tmp/container-setup.sh && chmod +x /tmp/container-setup.sh"

# Build setup command with arguments
SETUP_ARGS="--user dev"
if [ -n "$GITHUB_USERNAME" ]; then
    SETUP_ARGS="$SETUP_ARGS --github-user $GITHUB_USERNAME"
fi
if [ -n "$GITHUB_TOKEN" ]; then
    # Pass token securely via environment variable to avoid exposing in process list
    log_info "GitHub token will be configured in container"
    pct exec $CTID -- bash -c "GITHUB_TOKEN='$GITHUB_TOKEN' /tmp/container-setup.sh $SETUP_ARGS"
else
    log_info "Running setup inside container..."
    pct exec $CTID -- /tmp/container-setup.sh $SETUP_ARGS
fi

# Get the dev password from container
DEV_PASSWORD=$(pct exec $CTID -- cat /tmp/user_password.txt 2>/dev/null || echo "")
pct exec $CTID -- rm -f /tmp/container-setup.sh /tmp/user_password.txt

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
log_info "Access:"
log_info "  SSH: ssh dev@${CONTAINER_IP:-<CONTAINER_IP>}"
if [ -n "$DEV_PASSWORD" ]; then
    log_info "  Dev password: $DEV_PASSWORD"
fi
if [ -n "$GITHUB_USERNAME" ]; then
    log_info "  GitHub SSH keys: Added for $GITHUB_USERNAME"
fi
if [ -n "$GITHUB_TOKEN" ]; then
    log_info "  GitHub CLI: Authenticated"
fi
log_info ""
log_info "Root password: $CT_PASSWORD"
log_info ""
log_info "IMPORTANT: Save these passwords securely!"
if [ -z "$GITHUB_TOKEN" ]; then
    log_info ""
    log_info "TIP: To enable GitHub CLI authentication, use --github-token parameter"
    log_info "     Create a token at: https://github.com/settings/tokens"
    log_info "     Required scopes: 'repo' and 'read:org'"
fi