# LazyVim Devbox

A comprehensive development environment with Neovim, LazyVim, and modern development tools. Works in both Docker containers and Proxmox CTs/VMs.

## Features

- 🚀 Neovim 0.10.2 with LazyVim configuration
- 🐍 Python development (pyright, ruff, black, debugpy)
- 📦 TypeScript/JavaScript support (tsserver, eslint, prettier)
- 🎨 Lazygit integration
- 🤖 Claude Code CLI
- ⚡ uv - Fast Python package manager
- 🔧 Architecture support (amd64/arm64)

## Quick Start

### Option 1: Docker (Original Method)

```bash
# Setup SSH keys
mkdir -p ssh && chmod 700 ssh
cat ~/.ssh/id_rsa.pub >> ssh/authorized_keys && chmod 600 ssh/authorized_keys

# Build and run
docker compose build --no-cache devbox
docker compose up -d devbox

# Connect
ssh dev@localhost -p 2222
```

Toggle LazyVim setup by setting `RUN_LAZYVIM_SETUP` in docker-compose.yml:
- First run: Set to `1` 
- Subsequent runs: Set to `0`

### Option 2: Proxmox CT / Native Ubuntu

#### One-liner Installation

```bash
# Install for current user
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/lazyvim-devbox/main/setup.sh | bash

# Or create a dev user
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/lazyvim-devbox/main/setup.sh | bash -s -- --create-user dev
```

#### Clone and Install

```bash
git clone https://github.com/YOUR_USER/lazyvim-devbox.git
cd lazyvim-devbox
./setup.sh
```

#### Installation Options

```bash
./setup.sh [OPTIONS]

Options:
  --user USER         Install for specified user (default: current user)
  --create-user USER  Create new user and install (default: dev)
  --setup-ssh         Configure SSH server
  --workspace DIR     Set workspace directory (default: /workspace)
  --skip-lazyvim      Skip LazyVim installation
  --help              Show help message
```

## Project Structure

```
lazyvim-devbox/
├── setup.sh                 # Main installer (auto-detects environment)
├── Dockerfile              # Docker container definition
├── docker-compose.yml      # Docker orchestration
├── docker/                 # Docker-specific files
│   ├── entrypoint.sh      # Container startup script
│   └── install_lazyvim.sh # LazyVim installer (shared)
├── plugins/               # Neovim plugin configurations
│   ├── disable.lua       # Disabled default plugins
│   ├── lazygit.lua      # Lazygit integration
│   ├── python.lua       # Python development
│   └── ts.lua           # TypeScript/JavaScript
├── scripts/              # Installation scripts
│   ├── install-base.sh  # Base packages
│   ├── install-neovim.sh # Neovim installation
│   ├── install-tools.sh  # Dev tools (lazygit, node, claude, uv)
│   └── setup-user.sh    # User creation and SSH
└── workspace/           # Shared workspace directory
```

## Neovim Key Bindings

### LazyGit
- `<leader>gg` - Open LazyGit
- `<leader>gG` - Open LazyGit for current file
- `<leader>gf` - LazyGit filter
- `<leader>gF` - LazyGit filter for current file

### General LazyVim
- `<leader>` - Show which-key menu
- `<leader>ff` - Find files
- `<leader>fg` - Live grep
- `<leader>fb` - Browse buffers

## Environment Variables

Control installation behavior:

```bash
INSTALL_USER=dev           # Target user for installation
CREATE_USER=false          # Create new user
SETUP_SSH=false           # Configure SSH server
WORKSPACE_DIR=/workspace  # Workspace directory
SKIP_LAZYVIM=false       # Skip LazyVim setup
```

## Customization

### Adding Language Support

Create a new plugin file in `plugins/` directory:

```lua
-- plugins/rust.lua
return {
  {
    "williamboman/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "rust_analyzer" })
    end,
  },
}
```

### Modifying Tools

Edit scripts in `scripts/` directory to add or modify tool installations.

## Troubleshooting

### Permission Issues
If you encounter permission errors, ensure you're running as root or with sudo:
```bash
sudo ./setup.sh --create-user dev
```

### Architecture Detection
The installer automatically detects amd64/arm64. If detection fails, check:
```bash
dpkg --print-architecture
```

### LazyVim Already Installed
The installer checks for existing installations. To force reinstall:
```bash
rm ~/.config/nvim/.lazyvim_installed
./setup.sh
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Test in both Docker and native environments
4. Submit a pull request

## License

MIT