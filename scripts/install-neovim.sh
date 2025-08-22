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
else
    sudo tar -xzf /tmp/nvim.tar.gz -C /opt
fi

log_info "Neovim extracted successfully"

# Debug: Check what was actually extracted
log_info "Checking extracted contents in /opt:"
ls -la /opt/ | grep nvim || true

# Find the actual nvim directory name (it might vary)
NVIM_DIR=$(find /opt -maxdepth 1 -type d -name "nvim*" | head -1)
if [ -z "$NVIM_DIR" ]; then
    log_error "No nvim directory found in /opt after extraction"
    log_info "Contents of /opt:"
    ls -la /opt/
    exit 1
fi

log_info "Found Neovim directory: $NVIM_DIR"

# Check if binary exists
if [ ! -f "$NVIM_DIR/bin/nvim" ]; then
    log_error "nvim binary not found at $NVIM_DIR/bin/nvim"
    log_info "Contents of $NVIM_DIR:"
    ls -la "$NVIM_DIR/" || true
    if [ -d "$NVIM_DIR/bin" ]; then
        log_info "Contents of $NVIM_DIR/bin:"
        ls -la "$NVIM_DIR/bin/" || true
    fi
    exit 1
fi

# Create symlink
if [ "$EUID" -eq 0 ]; then
    mkdir -p /usr/local/bin
    ln -sf "$NVIM_DIR/bin/nvim" /usr/local/bin/nvim
    log_info "Created symlink: /usr/local/bin/nvim -> $NVIM_DIR/bin/nvim"
else
    sudo mkdir -p /usr/local/bin
    sudo ln -sf "$NVIM_DIR/bin/nvim" /usr/local/bin/nvim
    log_info "Created symlink: /usr/local/bin/nvim -> $NVIM_DIR/bin/nvim"
fi

# Also add to PATH for current session if needed
export PATH="/usr/local/bin:$PATH"

# Check symlink
ls -la /usr/local/bin/nvim || log_error "Symlink not created at /usr/local/bin/nvim"

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