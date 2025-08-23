# Lazyvimmer - Project Documentation

## Overview
Minimal scripts for creating development containers on Proxmox with Python 3.12 and Node.js LTS. Designed to be the foundation for various development environments that can be extended as needed.

## Current Architecture

### Core Components
- **Base**: Ubuntu 24.04 LTS (no fallback)
- **Python**: 3.12 from official Ubuntu repositories
- **Node.js**: Latest LTS via nvm v0.40.3
- **Package Manager**: uv for Python package management
- **Claude Code CLI**: Anthropic's official CLI tool
- **GitHub CLI**: gh command for GitHub operations
- **User**: 'dev' user with sudo access
- **SSH**: GitHub key authentication support
- **Networking**: DHCP only (vmbr0 bridge)

### File Structure
```
lazyvimmer/
├── proxmox-setup.sh    # Proxmox host script for CT creation
├── container-setup.sh  # Standalone container configuration
├── README.md          # User documentation
└── CLAUDE.md          # This file - AI context
```

## Scripts

### proxmox-setup.sh (v2.0)
Runs on Proxmox host to create and configure containers:
- Auto-detects available container ID (100-999)
- Checks for existing containers by name (idempotent)
- Downloads Ubuntu 24.04 template from Proxmox repository
- Creates unprivileged container with nesting enabled
- Configures networking with DHCP on vmbr0 bridge
- Fetches SSH keys from GitHub
- Generates secure random passwords for root and dev users
- Executes embedded setup script inside container
- Displays container IP address after creation

Key features:
- `--force` flag to recreate existing containers
- Automatic template detection from `pveam available`
- No fallback to older Ubuntu versions (fails if 24.04 unavailable)
- Embedded container setup script for streamlined deployment
- Password display only during setup (not stored)

### container-setup.sh
Standalone script for configuring any Ubuntu 24.04 container:
- Updates system packages
- Installs Python 3.12 and pip
- Installs Node.js LTS via nvm for the specified user
- Installs Claude Code CLI (@anthropic-ai/claude-code)
- Installs uv for Python package management
- Installs GitHub CLI (gh command)
- Creates user with sudo access (NOPASSWD)
- Configures SSH with GitHub key support
- Generates random passwords
- Installs additional dev tools (vim, nano, htop, net-tools, etc.)

**Idempotent Features** (safe to run multiple times):
- Checks if user exists before creating
- Ensures sudo permissions even for existing users
- Detects existing nvm installation and updates Node.js to latest LTS
- Installs or updates Claude Code CLI as needed
- Updates uv if already installed
- Prevents duplicate GitHub SSH keys
- Only installs GitHub CLI if not present, updates if exists
- Preserves existing configurations

Can be run independently in Docker containers or existing VMs. Safe for updating existing containers with new features.

## Design Decisions

### Why Ubuntu 24.04 with no fallback
- Latest LTS with Python 3.12 in main repos
- Consistency across all deployments
- Clear failure if requirements not met

### Why nvm for Node.js
- User-space installation (no root needed for updates)
- Easy version switching
- Standard in Node.js development

### Why random passwords
- Security by default
- Displayed once during setup
- Forces user to save credentials

### Why DHCP only
- Simplifies configuration
- Works in most environments
- Reduces user input requirements

## Common Issues and Solutions

### Template not found
**Problem**: "Ubuntu 24.04 template not found in Proxmox repository"

**Solution**: 
1. Check Proxmox repository configuration
2. Run `pveam update` manually
3. Verify with `pveam available | grep ubuntu`

### Container already exists
**Problem**: Container with same name exists

**Solution**: Use `--force` flag to recreate:
```bash
./proxmox-setup.sh --name mycontainer --force
```

### SSH keys not added
**Problem**: GitHub SSH keys not fetched

**Solution**: 
1. Verify GitHub username is correct
2. Check if user has public keys on GitHub
3. Manually add keys to container if needed

### Updating existing containers
**Problem**: Need to add new features to existing container

**Solution**: Run container-setup.sh again (it's idempotent):
```bash
# From inside the container
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | sudo bash -s -- --github-user yourusername

# Or from Proxmox host
pct push <CTID> container-setup.sh /tmp/setup.sh
pct exec <CTID> -- bash /tmp/setup.sh --github-user yourusername
```

## Future Extension Points

This minimal setup is designed to be extended with:
- Development tools (editors, debuggers)
- Language-specific environments
- Docker support
- Database tools
- CI/CD integration

The separation of `proxmox-setup.sh` and `container-setup.sh` allows for:
- Shared components between Docker and Proxmox
- Modular tool installation
- Environment-specific configurations

## Testing Checklist

When making changes, verify:
- [ ] Container creation on fresh Proxmox
- [ ] Idempotent container creation (same name)
- [ ] Force recreate with `--force`
- [ ] GitHub SSH key fetching
- [ ] Password generation and display
- [ ] Python 3.12 installation
- [ ] Node.js LTS via nvm
- [ ] Claude Code CLI installation
- [ ] uv Python package manager installation
- [ ] GitHub CLI (gh) installation
- [ ] User creation and sudo access
- [ ] SSH connectivity
- [ ] Dev tools installation (vim, nano, htop, etc.)

## Command Line Arguments

### proxmox-setup.sh
```bash
./proxmox-setup.sh [OPTIONS]
  --ctid ID          Container ID (auto-detect if not specified)
  --name NAME        Container name (default: devbox-YYMMDD)
  --memory MB        Memory in MB (default: 4096)
  --cores N          CPU cores (default: 2)
  --disk GB          Disk size in GB (default: 20)
  --storage NAME     Storage pool (default: local-zfs)
  --github-user NAME GitHub username for SSH keys
  --force            Force recreate if container exists
```

### container-setup.sh
```bash
./container-setup.sh [OPTIONS]
  --user NAME        User to create (default: dev)
  --github-user NAME GitHub username for SSH keys
  --no-ssh          Skip SSH server installation
```

## Version History

### v2.2 (Current)
- Added Claude Code CLI installation (@anthropic-ai/claude-code)
- Installs globally via npm with automatic updates

### v2.1
- Made container-setup.sh fully idempotent
- Safe to run multiple times for updates
- Prevents duplicate SSH keys
- Updates existing installations (nvm, uv, gh)
- Preserves existing user configurations
- Fixed SSH service name for Ubuntu 24.04 (uses 'ssh' not 'sshd')
- Added locale configuration to fix locale warnings (en_US.UTF-8)

### v2.0
- Added uv Python package manager
- Added GitHub CLI (gh command)
- Simplified to minimal Python + Node.js setup
- Removed all LazyVim/Neovim components
- Ubuntu 24.04 only (no fallback)
- Better template detection
- Random password generation
- Additional dev tools included

### v1.0 (Deprecated)
- Full LazyVim development environment
- Complex multi-script setup
- Ubuntu 22.04 with fallback support
- update  claude.md after every commit