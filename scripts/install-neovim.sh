#!/usr/bin/env bash
set -euo pipefail

# Install Neovim with architecture detection

NEOVIM_VERSION="${NEOVIM_VERSION:-0.10.2}"

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

log_info "Installing Neovim ${NEOVIM_VERSION}..."

# Detect architecture
ARCH="$(dpkg --print-architecture)"
log_info "Detected architecture: $ARCH"

# Determine download filename based on architecture
case "$ARCH" in
    amd64)
        FN1="nvim-linux64.tar.gz"
        FN2="nvim-linux-x86_64.tar.gz"
        ;;
    arm64)
        FN1="nvim-linux-arm64.tar.gz"
        FN2="$FN1"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Try to download Neovim
DOWNLOAD_SUCCESS=false
for FN in "$FN1" "$FN2"; do
    URL="https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/${FN}"
    log_info "Trying to download from: $URL"
    
    if curl -fsSL -o /tmp/nvim.tar.gz "$URL"; then
        DOWNLOAD_SUCCESS=true
        log_info "Successfully downloaded $FN"
        break
    fi
done

if [ "$DOWNLOAD_SUCCESS" = "false" ]; then
    log_error "Failed to download Neovim ${NEOVIM_VERSION}"
    exit 1
fi

# Extract and install
log_info "Extracting Neovim..."
if [ "$EUID" -eq 0 ]; then
    tar -xzf /tmp/nvim.tar.gz -C /opt
    DIR="$(tar -tzf /tmp/nvim.tar.gz | head -1 | cut -d/ -f1)"
    ln -sf "/opt/${DIR}/bin/nvim" /usr/local/bin/nvim
else
    sudo tar -xzf /tmp/nvim.tar.gz -C /opt
    DIR="$(tar -tzf /tmp/nvim.tar.gz | head -1 | cut -d/ -f1)"
    sudo ln -sf "/opt/${DIR}/bin/nvim" /usr/local/bin/nvim
fi

# Cleanup
rm /tmp/nvim.tar.gz

# Verify installation
if nvim --version | head -n1; then
    log_info "Neovim installed successfully"
else
    log_error "Neovim installation verification failed"
    exit 1
fi