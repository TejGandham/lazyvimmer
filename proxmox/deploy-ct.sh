#!/usr/bin/env bash
# One-liner deployment wrapper for LazyVim Devbox on Proxmox
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox/deploy-ct.sh)

set -euo pipefail

# Configuration - Edit these or pass as environment variables
GITHUB_USER="${GITHUB_USER:-TejGandham}"
CT_NAME="${CT_NAME:-lazyvim-$(date +%y%m%d)}"
CT_MEMORY="${CT_MEMORY:-4096}"
CT_CORES="${CT_CORES:-2}"
CT_DISK="${CT_DISK:-20}"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== LazyVim Devbox Quick Deploy ===${NC}"
echo "This will create a new Proxmox CT with LazyVim development environment"
echo

# Check if we're on Proxmox
if ! command -v pct &>/dev/null; then
    echo -e "${YELLOW}Error: This script must be run on a Proxmox host${NC}"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Error: This script must be run as root${NC}"
    exit 1
fi

# Try to detect SSH key
SSH_KEY_FILE=""
if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    SSH_KEY_FILE="$HOME/.ssh/id_rsa.pub"
elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    SSH_KEY_FILE="$HOME/.ssh/id_ed25519.pub"
fi

if [ -n "$SSH_KEY_FILE" ]; then
    echo -e "${GREEN}Found SSH key: $SSH_KEY_FILE${NC}"
else
    echo -e "${YELLOW}No SSH key found. You'll need to use 'pct enter' for initial access${NC}"
fi

# Show configuration
echo
echo "Configuration:"
echo "  GitHub User: $GITHUB_USER"
echo "  Container Name: $CT_NAME"
echo "  Memory: ${CT_MEMORY}MB"
echo "  CPU Cores: $CT_CORES"
echo "  Disk Size: ${CT_DISK}GB"
echo

# Ask for confirmation
read -p "Continue with deployment? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Download and run the main creation script
echo
echo -e "${BLUE}Downloading creation script...${NC}"
curl -fsSL "https://raw.githubusercontent.com/${GITHUB_USER}/lazyvimmer/main/proxmox/create-lazyvim-ct.sh" -o /tmp/create-lazyvim-ct.sh
chmod +x /tmp/create-lazyvim-ct.sh

# Run with our configuration
echo -e "${BLUE}Creating container...${NC}"
/tmp/create-lazyvim-ct.sh \
    --name "$CT_NAME" \
    --memory "$CT_MEMORY" \
    --cores "$CT_CORES" \
    --disk "$CT_DISK" \
    --github-user "$GITHUB_USER" \
    ${SSH_KEY_FILE:+--ssh-key-file "$SSH_KEY_FILE"}

# Cleanup
rm -f /tmp/create-lazyvim-ct.sh

echo
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo "Your LazyVim devbox is ready!"
echo
echo "Next steps:"
echo "1. Note the IP address shown above"
echo "2. SSH to your devbox: ssh dev@<IP_ADDRESS>"
echo "3. Start coding with: nvim"