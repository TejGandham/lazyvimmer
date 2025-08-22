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
log_info "Extracting Neovim to /opt..."

# Create /opt if it doesn't exist
if [ ! -d /opt ]; then
    if [ "$EUID" -eq 0 ]; then
        mkdir -p /opt
    else
        sudo mkdir -p /opt
    fi
fi

# Extract with verbose output for debugging
if [ "$EUID" -eq 0 ]; then
    tar -xzvf /tmp/nvim.tar.gz -C /opt 2>&1 | head -20
    # Neovim archive structure is predictable: nvim-linux64 or nvim-linux-arm64
    if [ "$ARCH" = "amd64" ]; then
        ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
    else
        ln -sf /opt/nvim-linux-arm64/bin/nvim /usr/local/bin/nvim
    fi
else
    sudo tar -xzvf /tmp/nvim.tar.gz -C /opt 2>&1 | head -20
    if [ "$ARCH" = "amd64" ]; then
        sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
    else
        sudo ln -sf /opt/nvim-linux-arm64/bin/nvim /usr/local/bin/nvim
    fi
fi

log_info "Neovim extracted successfully"

# Cleanup
rm /tmp/nvim.tar.gz

# Verify installation
if nvim --version | head -n1; then
    log_info "Neovim installed successfully"
else
    log_error "Neovim installation verification failed"
    exit 1
fi