#!/usr/bin/env bash
set -euo pipefail

# Finish Neovim setup - install remaining packages if initial setup was incomplete

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

# Run as the target user
INSTALL_USER="${INSTALL_USER:-${SUDO_USER:-${USER:-$(whoami)}}}"

log_info "Finishing Neovim setup for user: $INSTALL_USER"

# Function to run as target user
run_as_user() {
    if [ "$INSTALL_USER" = "$(whoami)" ] || [ "$INSTALL_USER" = "root" -a "$EUID" -eq 0 ]; then
        bash -c "$1"
    else
        sudo -u "$INSTALL_USER" -H bash -c "$1"
    fi
}

# Ensure all LazyVim plugins are installed
log_info "Ensuring all LazyVim plugins are installed..."
run_as_user 'nvim --headless "+Lazy! sync" +qa' || true

# Wait for plugins to load
sleep 3

# Install/update Mason packages
log_info "Installing Mason packages..."
run_as_user 'nvim --headless "+MasonInstallAll" +qa' 2>/dev/null || {
    # Fallback to manual installation
    log_info "Trying manual Mason package installation..."
    
    cat >/tmp/mason_complete.lua <<'LUA'
vim.cmd("Mason")

-- Wait for Mason to initialize
vim.wait(2000)

local mason = require("mason")
local mr = require("mason-registry")

-- Ensure registry is up to date
mr.refresh(function()
    local packages = {
        "pyright",
        "ruff-lsp",
        "typescript-language-server", 
        "eslint-lsp",
        "black",
        "prettier",
        "debugpy",
        "js-debug-adapter",
        "stylua",
        "shfmt",
    }
    
    for _, name in ipairs(packages) do
        local ok, pkg = pcall(mr.get_package, name)
        if ok and not pkg:is_installed() then
            vim.notify("Installing " .. name)
            pkg:install()
        end
    end
end)

-- Give time for installations
vim.wait(20000)
LUA
    
    run_as_user 'nvim --headless "+luafile /tmp/mason_complete.lua" +qa' || true
    rm -f /tmp/mason_complete.lua
}

# Install Treesitter parsers
log_info "Installing Treesitter parsers..."
run_as_user 'nvim --headless "+TSUpdateSync" +qa' 2>/dev/null || {
    log_info "Trying alternative Treesitter installation..."
    run_as_user 'nvim --headless "+TSInstall! all" +qa' 2>/dev/null || true
}

# Final sync to ensure everything is ready
log_info "Final plugin sync..."
run_as_user 'nvim --headless "+Lazy! sync" +qa' || true

log_info "Neovim setup complete!"
log_info "Note: First launch of nvim may still install some remaining components."