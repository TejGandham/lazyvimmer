# LazyVim Devbox - Proxmox CT Automation

Automated deployment of LazyVim development environment as a Proxmox container.

## Quick Start (One-Liner)

```bash
# RECOMMENDED: Use your GitHub SSH keys for remote access
GITHUB_USERNAME=yourusername bash <(curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox/deploy-ct.sh)

# Or with a custom container name:
CT_NAME=my-dev GITHUB_USERNAME=yourusername bash <(curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox/deploy-ct.sh)

# Basic (will use Proxmox host's SSH keys if available):
bash <(curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox/deploy-ct.sh)
```

**Note:** The script is idempotent! If a container with the same name already exists, it will show its status instead of creating a new one. Use `--force` to recreate.

This creates a fully configured Ubuntu 22.04 CT with:
- Neovim 0.10.2 + LazyVim
- Python & TypeScript/JavaScript development tools
- Language servers and debuggers
- SSH access as 'dev' user
- 4GB RAM, 2 CPU cores, 20GB disk (configurable)

## What Gets Installed

- **Editor**: Neovim with LazyVim configuration
- **Languages**: Python (pyright, ruff, black) and TypeScript/JavaScript (tsserver, eslint, prettier)
- **Tools**: lazygit, ripgrep, fd, uv, Claude Code CLI
- **Access**: SSH server with key authentication
- **User**: 'dev' with sudo privileges

## Customization

### Environment Variables

```bash
# Customize before running the one-liner:
export GITHUB_USER="your-github-username"
export CT_MEMORY=8192  # 8GB RAM
export CT_CORES=4      # 4 CPU cores
export CT_DISK=50      # 50GB disk

bash <(curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/lazyvimmer/main/proxmox/deploy-ct.sh)
```

### Direct Script Usage

For more control, download and run the creation script directly:

```bash
# Download the script
wget https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox/create-lazyvim-ct.sh
chmod +x create-lazyvim-ct.sh

# Run with custom options
./create-lazyvim-ct.sh \
  --name my-devbox \
  --memory 8192 \
  --cores 4 \
  --disk 50 \
  --ip 192.168.1.100/24 \
  --gateway 192.168.1.1 \
  --ssh-key-file ~/.ssh/id_rsa.pub
```

### Available Options

| Option | Description | Default |
|--------|-------------|---------|
| `--ctid` | Container ID | Auto (200-299) |
| `--name` | Container hostname | lazyvimmer |
| `--memory` | Memory in MB | 4096 |
| `--cores` | CPU cores | 2 |
| `--disk` | Disk size in GB | 20 |
| `--storage` | Storage location | local-zfs |
| `--bridge` | Network bridge | vmbr0 |
| `--ip` | IP address or 'dhcp' | dhcp |
| `--gateway` | Gateway IP | (none) |
| `--ssh-key` | SSH public key string | (none) |
| `--ssh-key-file` | SSH public key file | (none) |
| `--github-username` | GitHub user for SSH keys | (none) |
| `--github-user` | GitHub username | TejGandham |
| `--no-start` | Don't start after creation | false |
| `--force` | Force recreate existing container | false |

## Usage Workflow

1. **Run the one-liner** on your Proxmox host
2. **Wait 2-3 minutes** for automatic setup
3. **SSH into the container**:
   ```bash
   ssh dev@<container-ip>
   ```
4. **Start coding** with `nvim`

## Network Configuration

### DHCP (Default)
The container will get an IP from your DHCP server:
```bash
./create-lazyvim-ct.sh  # Uses DHCP by default
```

### Static IP
Specify IP and gateway for static configuration:
```bash
./create-lazyvim-ct.sh --ip 192.168.1.100/24 --gateway 192.168.1.1
```

## SSH Access

### Multiple SSH Key Sources (Can Use Together)

The script supports multiple SSH key sources for flexible access management:

#### 1. GitHub SSH Keys (RECOMMENDED)
```bash
# Use your GitHub account's public keys
./create-lazyvim-ct.sh --github-username yourusername
```

#### 2. Local SSH Key File
```bash
# Specify a key file from your workstation
./create-lazyvim-ct.sh --ssh-key-file /path/to/key.pub
```

#### 3. Direct SSH Key String
```bash
# Provide key directly
./create-lazyvim-ct.sh --ssh-key "ssh-rsa AAAAB3..."
```

#### 4. Multiple Sources
```bash
# Add keys from multiple sources (team access)
./create-lazyvim-ct.sh \
  --github-username developer1 \
  --ssh-key-file /path/to/team-keys.pub
```

#### 5. Automatic Fallback
If no keys are specified, the script checks for local keys:
- `~/.ssh/id_rsa.pub`
- `~/.ssh/id_ed25519.pub`
- `~/.ssh/id_ecdsa.pub`

### Without SSH Key
If no SSH key is available, use Proxmox console:
```bash
pct enter <ctid>
su - dev
```

## Troubleshooting

### Check Setup Progress
```bash
# View setup logs
pct exec <ctid> -- tail -f /var/log/lazyvim-setup.log
```

### Verify Container Status
```bash
# Check if container is running
pct status <ctid>

# Get container IP
pct exec <ctid> -- ip addr show eth0
```

### Manual Setup
If automatic setup fails, manually run inside the container:
```bash
pct enter <ctid>
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/setup.sh | bash
```

## Requirements

- Proxmox VE 7.x or 8.x
- Root access on Proxmox host
- Internet connectivity for downloading packages
- Ubuntu 22.04 template (auto-downloaded if missing)

## Architecture Support

Supports both amd64 and arm64 architectures with automatic detection.

## Security Notes

- Container runs unprivileged with nesting enabled
- 'dev' user has passwordless sudo (for development convenience)
- Root password is randomly generated and displayed once
- SSH password authentication is disabled by default

## Customizing the Setup

To modify what gets installed, edit these files before deployment:

1. Fork the repository
2. Update `GITHUB_USER` in scripts
3. Modify installation scripts as needed
4. Run the one-liner with your GitHub username

## Idempotency Features

The script supports idempotent operations:

1. **Check for existing container**: If a container with the same name exists, it will:
   - Show the container status (running/stopped)
   - Display the IP address if running
   - Provide the SSH command to connect
   - Exit without creating a duplicate

2. **Force recreate**: Use `--force` to destroy and recreate an existing container:
   ```bash
   ./create-lazyvim-ct.sh --name my-dev --force
   ```

3. **Safe re-runs**: Running the script multiple times with the same name won't create duplicates

## Complete Example

```bash
# On Proxmox host as root:
export GITHUB_USER="myusername"
export CT_NAME="dev-workspace"
export CT_MEMORY=8192

# First run - creates the container
bash <(curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/lazyvimmer/main/proxmox/deploy-ct.sh)

# Second run - shows existing container info
bash <(curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/lazyvimmer/main/proxmox/deploy-ct.sh)

# Force recreate
./create-lazyvim-ct.sh --name dev-workspace --force

# SSH in with the displayed IP
ssh dev@10.0.0.123

# Inside the container
cd /workspace
nvim
```

Your LazyVim development environment is now ready!