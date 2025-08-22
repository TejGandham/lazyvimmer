#!/usr/bin/env bash
set -euo pipefail

# Finish Neovim setup - simplified version that doesn't hang

log_info() { echo "[INFO] $1"; }

# Run as the target user
INSTALL_USER="${INSTALL_USER:-${SUDO_USER:-${USER:-$(whoami)}}}"

log_info "Finalizing Neovim setup for user: $INSTALL_USER"

# Function to run as target user
run_as_user() {
    if [ "$INSTALL_USER" = "$(whoami)" ] || [ "$INSTALL_USER" = "root" -a "$EUID" -eq 0 ]; then
        bash -c "$1"
    else
        sudo -u "$INSTALL_USER" -H bash -c "$1"
    fi
}

# Quick plugin sync
log_info "Syncing LazyVim plugins..."
timeout 30 bash -c "run_as_user 'nvim --headless \"+Lazy! sync\" +qa'" 2>/dev/null || true

log_info "Setup complete!"
log_info ""
log_info "IMPORTANT: Mason packages will auto-install on first Neovim launch."
log_info "This is normal and expected behavior for LazyVim."
log_info ""
log_info "To start using Neovim, simply run: nvim"