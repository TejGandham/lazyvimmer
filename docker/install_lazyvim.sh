#!/usr/bin/env bash
set -euo pipefail

# LazyVim installer - works for both Docker and native environments

# Determine if we need to use sudo
if [ "${INSTALL_USER:-}" = "" ]; then
    if [ -n "${SUDO_USER:-}" ]; then
        INSTALL_USER="$SUDO_USER"
    elif [ -n "${USER:-}" ]; then
        INSTALL_USER="$USER"
    else
        INSTALL_USER="$(whoami)"
    fi
fi

# Function to run as target user
run_as_user() {
    if [ "$INSTALL_USER" = "$(whoami)" ] || [ "$INSTALL_USER" = "root" -a "$EUID" -eq 0 ]; then
        bash -c "$1"
    else
        sudo -u "$INSTALL_USER" -H bash -c "$1"
    fi
}

# Main installation wrapped for user execution
run_as_user '
set -euo pipefail

NVIM_DIR="$HOME/.config/nvim"
PLUG_DIR="$NVIM_DIR/lua/plugins"

if [ -f "$NVIM_DIR/.lazyvim_installed" ]; then
  echo "LazyVim already installed. Skipping."
  exit 0
fi

BACKUP_TGZ="$HOME/nvim-backup-$(date +%s).tar.gz"
TMP="$(mktemp -d)"
STARTER="https://github.com/LazyVim/starter"

if [ -n "$(ls -A "$NVIM_DIR" 2>/dev/null || true)" ]; then
  tar -C "$NVIM_DIR" -czf "$BACKUP_TGZ" . || true
fi

git clone --depth=1 "$STARTER" "$TMP/nvim"
rm -rf "$TMP/nvim/.git"
rsync -a --delete "$TMP/nvim"/ "$NVIM_DIR"/
rm -rf "$TMP"

mkdir -p "$PLUG_DIR"

# Sync plugins first (this installs Lazy plugins including Mason)
echo "Syncing LazyVim plugins..."
nvim --headless "+lua require('lazy').sync({ wait = true, show = false })" +qa 2>/dev/null || true

# Wait a bit for plugins to settle
sleep 2

# Update Mason registry first
echo "Updating Mason registry..."
nvim --headless "+lua require('mason-registry').refresh()" +qa 2>/dev/null || true

# Install Mason packages with better error handling
echo "Installing LSP servers and tools..."
cat >/tmp/mason_install.lua <<'LUA'
local success, mason = pcall(require, "mason")
if not success then
  print("Mason not found, skipping package installation")
  return
end

local mr = require("mason-registry")

-- Refresh registry
mr.refresh()

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

for _, pkg_name in ipairs(packages) do
  local ok, pkg = pcall(mr.get_package, pkg_name)
  if ok then
    if not pkg:is_installed() then
      print("Installing " .. pkg_name .. "...")
      pkg:install()
    else
      print(pkg_name .. " already installed")
    end
  else
    print("Package not found: " .. pkg_name)
  end
end

-- Wait for installations to complete
vim.wait(30000, function()
  for _, pkg_name in ipairs(packages) do
    local ok, pkg = pcall(mr.get_package, pkg_name)
    if ok and pkg:is_installed() == false then
      return false
    end
  end
  return true
end, 1000)
LUA

nvim --headless "+luafile /tmp/mason_install.lua" +qa 2>/dev/null || true

# Install treesitter parsers
echo "Installing Treesitter parsers..."
nvim --headless "+TSUpdateSync" +qa 2>/dev/null || true

touch "$NVIM_DIR/.lazyvim_installed"
'
