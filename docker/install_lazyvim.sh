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

# Sync plugins
nvim --headless "+lua require('lazy').sync({ wait = true })" +qa || true

# Mason installs (blocking)
cat >/tmp/mason_install.lua <<'LUA'
local mr = require("mason-registry")
local pkgs = {
  "pyright","ruff-lsp","typescript-language-server","eslint-lsp",
  "black","prettier","debugpy","js-debug-adapter",
}
for _, name in ipairs(pkgs) do
  local ok, pkg = pcall(mr.get_package, name)
  if ok and not pkg:is_installed() then
    local h = pkg:install()
    if h and h.wait then h:wait() end
  end
end
LUA
nvim --headless "+luafile /tmp/mason_install.lua" +qa || true

touch "$NVIM_DIR/.lazyvim_installed"
'
