#!/usr/bin/env bash
set -euo pipefail

# Proxmox CT Setup Script
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
        --force) FORCE_RECREATE="true"; shift ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --ctid ID          Container ID (auto-detect if not specified)"
            echo "  --name NAME        Container name (default: devbox-YYMMDD)"
            echo "  --memory MB        Memory in MB (default: 4096)"
            echo "  --cores N          CPU cores (default: 2)"
            echo "  --disk GB          Disk size in GB (default: 20)"
            echo "  --storage NAME     Storage pool (default: local-zfs)"
            echo "  --github-user NAME GitHub username for SSH keys"
            echo "  --force            Force recreate if container exists"
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

log_info "Creating Ubuntu $UBUNTU_VERSION container"
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
TEMPLATE_NAME="ubuntu-${UBUNTU_VERSION}-standard_${UBUNTU_VERSION}-1_amd64.tar.zst"
TEMPLATE_PATH="/var/lib/vz/template/cache/${TEMPLATE_NAME}"

if [ ! -f "$TEMPLATE_PATH" ]; then
    log_info "Downloading Ubuntu $UBUNTU_VERSION template..."
    pveam update
    pveam download local "$TEMPLATE_NAME"
fi

# Create container
log_info "Creating container..."
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

# Create setup script
log_info "Creating container setup script..."
cat > /tmp/container-setup-$CTID.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Update system
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install basic tools
echo "Installing basic tools..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    sudo \
    openssh-server \
    ca-certificates \
    gnupg

# Install Python 3.12 (default in Ubuntu 24.04)
echo "Installing Python 3.12..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev

# Create dev user
echo "Creating dev user..."
useradd -m -s /bin/bash -G sudo dev
echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev

# Install Node.js via nvm for dev user
echo "Installing nvm and Node.js LTS..."
NVM_VERSION="v0.40.3"
sudo -u dev bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
sudo -u dev bash -c "
    export NVM_DIR=/home/dev/.nvm
    [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
    nvm install --lts
    nvm use --lts
    nvm alias default lts/*
"

# Add nvm to dev user's bashrc
if ! grep -q "NVM_DIR" /home/dev/.bashrc; then
    cat >> /home/dev/.bashrc << 'NVMEOF'

# NVM configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
NVMEOF
fi

# Setup SSH
echo "Configuring SSH..."
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Setup SSH keys for dev user
mkdir -p /home/dev/.ssh
touch /home/dev/.ssh/authorized_keys
chmod 700 /home/dev/.ssh
chmod 600 /home/dev/.ssh/authorized_keys
chown -R dev:dev /home/dev/.ssh

# Add GitHub SSH keys if provided
if [ -n "$1" ]; then
    echo "$1" >> /home/dev/.ssh/authorized_keys
    echo "Added SSH keys to dev user"
fi

# Generate and set random password for dev user
DEV_PASSWORD=$(openssl rand -base64 12)
echo "dev:$DEV_PASSWORD" | chpasswd
echo "$DEV_PASSWORD" > /tmp/dev_password.txt

# Verify installations
echo ""
echo "=== Installation Summary ==="
python3 --version
pip3 --version
sudo -u dev bash -c "source /home/dev/.nvm/nvm.sh && node --version"
sudo -u dev bash -c "source /home/dev/.nvm/nvm.sh && npm --version"
echo "User: dev"
if [ -f /tmp/dev_password.txt ]; then
    echo "Password: $(cat /tmp/dev_password.txt)"
fi
echo "SSH: Enabled"
echo "NVM: Installed with Node.js LTS"
echo "============================"
EOF

# Copy and run setup script in container
log_info "Running setup inside container..."
pct push $CTID /tmp/container-setup-$CTID.sh /tmp/setup.sh
pct exec $CTID -- chmod +x /tmp/setup.sh
pct exec $CTID -- /tmp/setup.sh "$SSH_KEYS"

# Get the dev password from container
DEV_PASSWORD=$(pct exec $CTID -- cat /tmp/dev_password.txt 2>/dev/null || echo "")
pct exec $CTID -- rm -f /tmp/setup.sh /tmp/dev_password.txt

# Cleanup
rm /tmp/container-setup-$CTID.sh

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
log_info ""
log_info "Root password: $CT_PASSWORD"
log_info ""
log_info "IMPORTANT: Save these passwords securely!"