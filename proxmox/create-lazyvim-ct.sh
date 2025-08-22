#!/usr/bin/env bash
set -euo pipefail

# Proxmox CT Creation Script for LazyVim Devbox
# Creates an Ubuntu 22.04 CT with automatic LazyVim setup

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Default configuration
CTID="${CTID:-}"
CT_NAME="${CT_NAME:-lazyvim-devbox}"
CT_MEMORY="${CT_MEMORY:-4096}"
CT_CORES="${CT_CORES:-2}"
CT_DISK="${CT_DISK:-20}"
CT_STORAGE="${CT_STORAGE:-local-lvm}"
CT_BRIDGE="${CT_BRIDGE:-vmbr0}"
CT_IP="${CT_IP:-dhcp}"
CT_GATEWAY="${CT_GATEWAY:-}"
CT_PASSWORD="${CT_PASSWORD:-$(openssl rand -base64 12)}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
GITHUB_USER="${GITHUB_USER:-YOUR_USER}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"
SSH_KEY_FILE="${SSH_KEY_FILE:-$HOME/.ssh/id_rsa.pub}"
UBUNTU_VERSION="${UBUNTU_VERSION:-22.04}"
START_AFTER_CREATE="${START_AFTER_CREATE:-true}"

# Function to find next available CTID
find_next_ctid() {
    local start_id="${1:-100}"
    local max_id="${2:-999}"
    
    for id in $(seq $start_id $max_id); do
        if ! pct status $id &>/dev/null; then
            echo $id
            return 0
        fi
    done
    
    log_error "No available CTID found between $start_id and $max_id"
    return 1
}

# Function to download Ubuntu template
download_template() {
    local template_name="ubuntu-${UBUNTU_VERSION}-standard_${UBUNTU_VERSION}-1_amd64.tar.zst"
    local template_path="/var/lib/vz/template/cache/${template_name}"
    
    if [ -f "$template_path" ]; then
        log_info "Template already exists: $template_name"
        return 0
    fi
    
    log_step "Downloading Ubuntu ${UBUNTU_VERSION} template..."
    pveam update
    pveam download $TEMPLATE_STORAGE ubuntu-${UBUNTU_VERSION}-standard_${UBUNTU_VERSION}-1_amd64.tar.zst
}

# Function to read SSH key
get_ssh_key() {
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        echo "$SSH_PUBLIC_KEY"
    elif [ -f "$SSH_KEY_FILE" ]; then
        cat "$SSH_KEY_FILE"
    else
        log_warn "No SSH key provided or found at $SSH_KEY_FILE"
        log_warn "You'll need to use password authentication initially"
        echo ""
    fi
}

# Function to create cloud-init snippets
create_cloud_init() {
    local ctid=$1
    local ssh_key="$2"
    
    log_step "Creating cloud-init configuration..."
    
    # Create snippets directory if it doesn't exist
    local snippets_dir="/var/lib/vz/snippets"
    mkdir -p "$snippets_dir"
    
    # Create user-data file
    cat > "$snippets_dir/lazyvim-${ctid}-user.yml" <<EOF
#cloud-config
hostname: ${CT_NAME}
manage_etc_hosts: true

users:
  - name: dev
    groups: [sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
EOF

    if [ -n "$ssh_key" ]; then
        echo "    ssh_authorized_keys:" >> "$snippets_dir/lazyvim-${ctid}-user.yml"
        echo "      - $ssh_key" >> "$snippets_dir/lazyvim-${ctid}-user.yml"
    fi
    
    cat >> "$snippets_dir/lazyvim-${ctid}-user.yml" <<EOF

package_update: true
package_upgrade: false

packages:
  - curl
  - wget
  - git
  - sudo
  - openssh-server

runcmd:
  # Ensure SSH is running
  - systemctl enable ssh
  - systemctl start ssh
  
  # Create workspace directory
  - mkdir -p /workspace
  - chown dev:dev /workspace
  
  # Download and run setup script
  - |
    export DEBIAN_FRONTEND=noninteractive
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/lazyvimmer/main/setup.sh -o /tmp/setup.sh
    chmod +x /tmp/setup.sh
    cd /tmp
    GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/lazyvimmer/main" \\
    INSTALL_USER=dev \\
    WORKSPACE_DIR=/workspace \\
    SKIP_LAZYVIM=false \\
    ./setup.sh
  
  # Mark setup as complete
  - touch /var/lib/cloud/instance/boot-finished
  - echo "LazyVim Devbox setup completed at \$(date)" >> /var/log/lazyvim-setup.log

final_message: |
  LazyVim Devbox setup complete!
  Container: ${CT_NAME} (ID: ${ctid})
  SSH access: ssh dev@\$IPADDRESS
EOF

    # Create meta-data file
    cat > "$snippets_dir/lazyvim-${ctid}-meta.yml" <<EOF
instance-id: lazyvim-${ctid}
local-hostname: ${CT_NAME}
EOF
}

# Function to create the container
create_container() {
    local ctid=$1
    local ssh_key="$2"
    
    log_step "Creating container ${CT_NAME} (ID: ${ctid})..."
    
    # Base pct create command
    local create_cmd="pct create ${ctid} ${TEMPLATE_STORAGE}:vztmpl/ubuntu-${UBUNTU_VERSION}-standard_${UBUNTU_VERSION}-1_amd64.tar.zst"
    create_cmd="$create_cmd --hostname ${CT_NAME}"
    create_cmd="$create_cmd --memory ${CT_MEMORY}"
    create_cmd="$create_cmd --cores ${CT_CORES}"
    create_cmd="$create_cmd --rootfs ${CT_STORAGE}:${CT_DISK}"
    create_cmd="$create_cmd --features nesting=1"
    create_cmd="$create_cmd --unprivileged 1"
    create_cmd="$create_cmd --ostype ubuntu"
    
    # Network configuration
    if [ "$CT_IP" = "dhcp" ]; then
        create_cmd="$create_cmd --net0 name=eth0,bridge=${CT_BRIDGE},ip=dhcp"
    else
        create_cmd="$create_cmd --net0 name=eth0,bridge=${CT_BRIDGE},ip=${CT_IP}"
        if [ -n "$CT_GATEWAY" ]; then
            create_cmd="$create_cmd,gw=${CT_GATEWAY}"
        fi
    fi
    
    # Set password for root (backup access)
    create_cmd="$create_cmd --password ${CT_PASSWORD}"
    
    # Add cloud-init if we created the snippets
    if [ -f "/var/lib/vz/snippets/lazyvim-${ctid}-user.yml" ]; then
        create_cmd="$create_cmd --cicustom user=local:snippets/lazyvim-${ctid}-user.yml,meta=local:snippets/lazyvim-${ctid}-meta.yml"
    fi
    
    # Execute creation
    eval $create_cmd
    
    log_info "Container created successfully!"
}

# Function to start the container
start_container() {
    local ctid=$1
    
    log_step "Starting container ${ctid}..."
    pct start ${ctid}
    
    # Wait for container to be running
    local max_wait=30
    local count=0
    while [ $count -lt $max_wait ]; do
        if pct status ${ctid} 2>/dev/null | grep -q "running"; then
            log_info "Container is running"
            break
        fi
        sleep 1
        count=$((count + 1))
    done
    
    if [ $count -eq $max_wait ]; then
        log_error "Container failed to start within ${max_wait} seconds"
        return 1
    fi
}

# Function to get container IP
get_container_ip() {
    local ctid=$1
    local max_wait=60
    local count=0
    
    log_step "Waiting for container to get IP address..."
    
    while [ $count -lt $max_wait ]; do
        local ip=$(pct exec ${ctid} -- ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
        sleep 2
        count=$((count + 2))
    done
    
    log_warn "Could not determine container IP after ${max_wait} seconds"
    echo ""
}

# Function to wait for setup completion
wait_for_setup() {
    local ctid=$1
    local ip=$2
    
    log_step "Waiting for LazyVim setup to complete (this may take 3-5 minutes)..."
    
    local max_wait=300  # 5 minutes
    local count=0
    
    while [ $count -lt $max_wait ]; do
        # Check if setup marker exists
        if pct exec ${ctid} -- test -f /var/lib/cloud/instance/boot-finished 2>/dev/null; then
            log_info "Setup completed successfully!"
            return 0
        fi
        
        # Show progress
        if [ $((count % 30)) -eq 0 ]; then
            log_info "Still setting up... ($((count/60))m elapsed)"
        fi
        
        sleep 5
        count=$((count + 5))
    done
    
    log_warn "Setup is taking longer than expected. You can check progress by logging into the container."
    return 1
}

# Main execution
main() {
    # Check if running on Proxmox host
    if ! command -v pct &>/dev/null; then
        log_error "This script must be run on a Proxmox host"
        exit 1
    fi
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    log_info "=== LazyVim Devbox CT Creator ==="
    log_info "Creating Ubuntu ${UBUNTU_VERSION} container with LazyVim development environment"
    echo
    
    # Find or use provided CTID
    if [ -z "$CTID" ]; then
        CTID=$(find_next_ctid 200 299)
        log_info "Using CTID: ${CTID}"
    else
        # Check if CTID is already in use
        if pct status $CTID &>/dev/null; then
            log_error "CTID ${CTID} is already in use"
            exit 1
        fi
    fi
    
    # Get SSH key
    SSH_KEY=$(get_ssh_key)
    
    # Download template
    download_template
    
    # Create cloud-init configuration
    create_cloud_init "$CTID" "$SSH_KEY"
    
    # Create container
    create_container "$CTID" "$SSH_KEY"
    
    # Start container if requested
    if [ "$START_AFTER_CREATE" = "true" ]; then
        start_container "$CTID"
        
        # Get container IP
        CT_IP=$(get_container_ip "$CTID")
        
        # Wait for setup to complete
        wait_for_setup "$CTID" "$CT_IP"
        
        echo
        log_info "=== Container Ready ==="
        log_info "Container ID: ${CTID}"
        log_info "Container Name: ${CT_NAME}"
        if [ -n "$CT_IP" ]; then
            log_info "IP Address: ${CT_IP}"
            log_info "SSH Command: ssh dev@${CT_IP}"
        else
            log_info "IP Address: Check with 'pct exec ${CTID} -- ip addr show'"
        fi
        log_info "Root Password: ${CT_PASSWORD} (saved for emergency access)"
        
        if [ -z "$SSH_KEY" ]; then
            log_warn "No SSH key was configured. Use 'pct enter ${CTID}' for initial access"
        fi
        
        echo
        log_info "LazyVim and all tools are installed and ready!"
        log_info "First login will initialize the Neovim plugins."
    else
        echo
        log_info "Container created but not started."
        log_info "To start: pct start ${CTID}"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ctid)
            CTID="$2"
            shift 2
            ;;
        --name)
            CT_NAME="$2"
            shift 2
            ;;
        --memory)
            CT_MEMORY="$2"
            shift 2
            ;;
        --cores)
            CT_CORES="$2"
            shift 2
            ;;
        --disk)
            CT_DISK="$2"
            shift 2
            ;;
        --storage)
            CT_STORAGE="$2"
            shift 2
            ;;
        --bridge)
            CT_BRIDGE="$2"
            shift 2
            ;;
        --ip)
            CT_IP="$2"
            shift 2
            ;;
        --gateway)
            CT_GATEWAY="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_PUBLIC_KEY="$2"
            shift 2
            ;;
        --ssh-key-file)
            SSH_KEY_FILE="$2"
            shift 2
            ;;
        --github-user)
            GITHUB_USER="$2"
            shift 2
            ;;
        --no-start)
            START_AFTER_CREATE=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --ctid ID           Container ID (default: auto-find 200-299)"
            echo "  --name NAME         Container hostname (default: lazyvim-devbox)"
            echo "  --memory MB         Memory in MB (default: 4096)"
            echo "  --cores N           CPU cores (default: 2)"
            echo "  --disk GB           Root disk size in GB (default: 20)"
            echo "  --storage STORAGE   Storage location (default: local-lvm)"
            echo "  --bridge BRIDGE     Network bridge (default: vmbr0)"
            echo "  --ip IP             IP address or 'dhcp' (default: dhcp)"
            echo "  --gateway GW        Gateway IP (required if using static IP)"
            echo "  --ssh-key KEY       SSH public key string"
            echo "  --ssh-key-file FILE SSH public key file (default: ~/.ssh/id_rsa.pub)"
            echo "  --github-user USER  GitHub username for setup script (default: YOUR_USER)"
            echo "  --no-start          Don't start container after creation"
            echo "  --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  # Create with defaults (DHCP, auto CTID)"
            echo "  $0"
            echo ""
            echo "  # Create with static IP"
            echo "  $0 --ip 192.168.1.100/24 --gateway 192.168.1.1"
            echo ""
            echo "  # Create with custom resources"
            echo "  $0 --memory 8192 --cores 4 --disk 50"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main