# LazyVimmer - Instant Dev Environment

Spin up a fully configured Neovim development environment in seconds. Works on Proxmox containers and Docker.

## Quick Start

### Proxmox (Recommended)
```bash
# With your GitHub SSH keys (for remote access):
GITHUB_USERNAME=yourusername bash <(curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox/deploy-ct.sh)

# Or basic (uses Proxmox host's SSH keys if available):
bash <(curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox/deploy-ct.sh)
```

That's it! In 2-3 minutes you'll have a container with:
- Neovim + LazyVim fully configured
- Python & TypeScript development tools
- SSH access as 'dev' user
- Claude Code CLI installed
- 4GB RAM, 2 CPU cores, 20GB disk

### Docker
```bash
git clone https://github.com/TejGandham/lazyvimmer.git
cd lazyvimmer
mkdir -p ssh && cp ~/.ssh/id_rsa.pub ssh/authorized_keys
docker compose up -d --build
ssh dev@localhost -p 2222
```

## What's Included

- **Neovim 0.10.2** with LazyVim configuration
- **Python**: pyright, ruff, black, debugpy
- **TypeScript/JavaScript**: tsserver, eslint, prettier, debugging
- **Tools**: lazygit, ripgrep, fd, uv, Claude Code CLI
- **User**: 'dev' with sudo access
- **SSH**: Key-based authentication

## Customization

### Proxmox Options

```bash
# Custom resources:
export CT_MEMORY=8192  # 8GB RAM
export CT_CORES=4      # 4 CPU cores
export CT_DISK=50      # 50GB disk

bash <(curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox/deploy-ct.sh)
```

### Direct Script Options

```bash
./proxmox/create-lazyvim-ct.sh \
  --name my-devbox \
  --memory 8192 \
  --cores 4 \
  --disk 50 \
  --ip 192.168.1.100/24 \
  --gateway 192.168.1.1
```

## Available Options

| Option | Description | Default |
|--------|-------------|---------|
| `--name` | Container hostname | lazyvimmer |
| `--memory` | Memory in MB | 4096 |
| `--cores` | CPU cores | 2 |
| `--disk` | Disk size in GB | 20 |
| `--ip` | IP address or 'dhcp' | dhcp |
| `--gateway` | Gateway IP | (none) |
| `--force` | Recreate if exists | false |

## Usage

```bash
# SSH into your new container (IP shown after creation)
ssh dev@<container-ip>

# Start coding
cd /workspace
nvim
```

## Key Bindings

- `<leader>` = space
- `<leader>gg` - Open lazygit
- `<leader>ff` - Find files
- `<leader>fg` - Find text
- `gd` - Go to definition
- `K` - Show documentation

## Idempotent & Safe

The script is idempotent - running it multiple times with the same name won't create duplicates:

```bash
# First run: Creates container
bash <(curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox/deploy-ct.sh)

# Second run: Shows existing container info
bash <(curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox/deploy-ct.sh)

# Force recreate with --force
./proxmox/create-lazyvim-ct.sh --name my-devbox --force
```

## Requirements

- **Proxmox**: VE 7.x or 8.x with root access
- **Docker**: Docker and Docker Compose (for Docker mode)
- Internet connectivity for package downloads

## Troubleshooting

```bash
# Check container status
pct status <ctid>

# View setup logs
pct exec <ctid> -- tail -f /var/log/lazyvim-setup.log

# Get container IP
pct exec <ctid> -- ip addr show eth0

# Manual setup if needed
pct enter <ctid>
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/setup.sh | bash
```

## Security Notes

- Container runs unprivileged with nesting enabled
- 'dev' user has passwordless sudo (for development convenience)
- Root password is randomly generated and displayed once
- SSH password authentication disabled by default

## More Documentation

Detailed documentation and advanced usage: [proxmox/README.md](proxmox/README.md)