# Lazyvimmer - Project Documentation

## Overview
Minimal scripts for creating development containers on Proxmox with Python 3.12 and Node.js LTS. Designed to be the foundation for various development environments that can be extended as needed.

## Current Architecture

### Core Components
- **Base**: Ubuntu 24.04 LTS (no fallback)
- **Python**: 3.12 from official Ubuntu repositories
- **Node.js**: Latest LTS via nvm v0.40.3
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

### proxmox-setup.sh
Runs on Proxmox host to create and configure containers:
- Auto-detects available container ID (100-999)
- Checks for existing containers by name (idempotent)
- Downloads Ubuntu 24.04 template from Proxmox repository
- Creates unprivileged container with nesting enabled
- Configures networking with DHCP
- Fetches SSH keys from GitHub
- Generates secure random passwords
- Executes embedded setup script inside container

Key features:
- `--force` flag to recreate existing containers
- Automatic template detection from `pveam available`
- No fallback to older Ubuntu versions (fails if 24.04 unavailable)

### container-setup.sh
Standalone script for configuring any Ubuntu 24.04 container:
- Updates system packages
- Installs Python 3.12 and pip
- Installs Node.js LTS via nvm for the specified user
- Creates user with sudo access
- Configures SSH with GitHub key support
- Generates random passwords

Can be run independently in Docker containers or existing VMs.

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
- [ ] User creation and sudo access
- [ ] SSH connectivity

## Version History

### v2.0 (Current)
- Simplified to minimal Python + Node.js setup
- Removed all LazyVim/Neovim components
- Ubuntu 24.04 only (no fallback)
- Better template detection
- Random password generation

### v1.0 (Deprecated)
- Full LazyVim development environment
- Complex multi-script setup
- Ubuntu 22.04 with fallback support