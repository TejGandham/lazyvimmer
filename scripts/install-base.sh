#!/usr/bin/env bash
set -euo pipefail

# Install base packages for Ubuntu

log_info() { echo "[INFO] $1"; }

log_info "Updating package lists..."
export DEBIAN_FRONTEND=noninteractive

if [ "$EUID" -eq 0 ]; then
    apt-get update -y
else
    sudo apt-get update -y
fi

log_info "Installing base development packages..."

PACKAGES=(
    # Essential tools
    git
    curl
    wget
    ca-certificates
    gnupg
    lsb-release
    
    # Build tools
    build-essential
    make
    unzip
    tar
    rsync
    
    # Search tools
    ripgrep
    fd-find
    
    # Python
    python3
    python3-venv
    python3-pip
    software-properties-common
    
    # Utils
    xz-utils
    sudo
)

if [ "$EUID" -eq 0 ]; then
    apt-get install -y --no-install-recommends "${PACKAGES[@]}"
else
    sudo apt-get install -y --no-install-recommends "${PACKAGES[@]}"
fi

# Create fd alias (Ubuntu names it fdfind)
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    log_info "Creating fd alias for fdfind..."
    if [ "$EUID" -eq 0 ]; then
        ln -sf /usr/bin/fdfind /usr/local/bin/fd
    else
        sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
    fi
fi

log_info "Base packages installed successfully"