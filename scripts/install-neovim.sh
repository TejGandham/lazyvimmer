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

# Extract quietly with progress indicator
if [ "$EUID" -eq 0 ]; then
    tar -xzf /tmp/nvim.tar.gz -C /opt
    # Ensure /usr/local/bin exists
    mkdir -p /usr/local/bin
    # Neovim archive structure is predictable: nvim-linux64 or nvim-linux-arm64
    if [ "$ARCH" = "amd64" ]; then
        ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
    else
        ln -sf /opt/nvim-linux-arm64/bin/nvim /usr/local/bin/nvim
    fi
else
    sudo tar -xzf /tmp/nvim.tar.gz -C /opt
    sudo mkdir -p /usr/local/bin
    if [ "$ARCH" = "amd64" ]; then
        sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
    else
        sudo ln -sf /opt/nvim-linux-arm64/bin/nvim /usr/local/bin/nvim
    fi
fi

# Also add to PATH for current session if needed
export PATH="/usr/local/bin:$PATH"

log_info "Neovim extracted successfully"

# Debug: Check what was extracted
if [ -d /opt/nvim-linux64 ]; then
    log_info "Found /opt/nvim-linux64"
    ls -la /opt/nvim-linux64/bin/nvim 2>/dev/null || log_error "nvim binary not found in /opt/nvim-linux64/bin/"
elif [ -d /opt/nvim-linux-arm64 ]; then
    log_info "Found /opt/nvim-linux-arm64"
    ls -la /opt/nvim-linux-arm64/bin/nvim 2>/dev/null || log_error "nvim binary not found in /opt/nvim-linux-arm64/bin/"
fi

# Check symlink
ls -la /usr/local/bin/nvim 2>/dev/null || log_error "Symlink not created at /usr/local/bin/nvim"

# Cleanup
rm -f /tmp/nvim.tar.gz

# Verify installation - try direct path first if command fails
if command -v nvim >/dev/null 2>&1; then
    NVIM_VERSION_OUTPUT=$(nvim --version 2>&1 | head -n1)
    log_info "Neovim installed successfully: $NVIM_VERSION_OUTPUT"
elif [ -x /usr/local/bin/nvim ]; then
    NVIM_VERSION_OUTPUT=$(/usr/local/bin/nvim --version 2>&1 | head -n1)
    log_info "Neovim installed successfully (direct path): $NVIM_VERSION_OUTPUT"
else
    log_error "Neovim installation verification failed - nvim command not found"
    log_error "PATH is: $PATH"
    exit 1
fi