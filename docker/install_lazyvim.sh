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

# The simplified approach - let LazyVim handle the rest on first real launch
echo "Configuring LSP servers and tools..."

# Create a custom config to ensure packages are marked for installation
cat > "$PLUG_DIR/ensure-mason.lua" <<'LUA'
return {
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "stylua",
        "shfmt",
      })
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "pyright",
        "ruff_lsp",
        "tsserver",
        "eslint",
      })
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "debugpy",
        "js-debug-adapter",
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.python = { "black" }
      opts.formatters_by_ft.javascript = { "prettier" }
      opts.formatters_by_ft.typescript = { "prettier" }
    end,
  },
}
LUA

echo "Initial setup complete. Packages will install on first Neovim launch."

touch "$NVIM_DIR/.lazyvim_installed"
'
