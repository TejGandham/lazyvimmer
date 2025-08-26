# Lazyvimmer - Technical Documentation & AI Context

## Executive Summary
Production-ready, idempotent scripts for creating minimal development containers on Proxmox with modern Python and Node.js. **Supports Ubuntu 24.04 LTS (stable) and Ubuntu Server 25.04 (latest)** - designed as a foundation for various development environments with emphasis on security, reproducibility, and extensibility.

## Current Architecture

### Core Components

#### Ubuntu 24.04 LTS (Stable Branch)
- **Base**: Ubuntu 24.04 LTS (5-year support, no fallback)
- **Python**: 3.12 from official Ubuntu repositories
- **Node.js**: Latest LTS via nvm v0.40.3 (multiple versions supported)
- **Package Management**: APT with PPA support

#### Ubuntu Server 25.04 (Latest Features Branch)
- **Base**: Ubuntu Server 25.04 "Plucky Puffin" (9-month support until January 2026)
- **Python**: 3.13.3 from official Ubuntu repositories
- **Node.js**: 20.18.1 via native apt packages (faster installation)
- **Package Management**: APT 3.0 with improved dependency resolver

#### Common Components (Both Distributions)
- **Package Manager**: uv for Python package management
- **Claude Code CLI**: Anthropic's official CLI tool
- **GitHub CLI**: gh command with optional PAT authentication
- **Docker** (Optional): Docker CE with Docker Compose v2 plugin
- **User**: 'dev' user with sudo access
- **SSH**: GitHub key authentication support
- **Networking**: DHCP only (vmbr0 bridge)

### File Structure
```
lazyvimmer/
├── proxmox-setup.sh               # Ubuntu 24.04 LTS - Proxmox host script for CT creation
├── container-setup.sh             # Ubuntu 24.04 LTS - Standalone container configuration  
├── proxmox-setup-ubuntu2504.sh    # Ubuntu 25.04 - Proxmox host script (two-phase)
├── container-setup-ubuntu2504.sh  # Ubuntu 25.04 - Standalone container configuration (two-phase)
├── README.md                      # User documentation (updated for both distros)
└── CLAUDE.md                      # This file - AI context
```

## Technical Implementation Details

### Container Architecture
- **Unprivileged LXC**: Runs without root mapping for enhanced security
- **Nesting Enabled**: Allows running Docker inside LXC containers
- **DHCP Networking**: Automatic IP assignment via vmbr0 bridge
- **Resource Limits**: Configurable CPU, memory, and disk constraints
- **Storage Backend**: Supports any Proxmox storage (local-zfs, local-lvm, etc.)

### Security Model
- **Password Generation**: 32-character random passwords using `/dev/urandom`
- **SSH Key Management**: Fetches public keys from GitHub profiles
- **Token Security**: GitHub PATs handled via environment variables, never logged
- **User Isolation**: Non-root 'dev' user with sudo (NOPASSWD) for development
- **Container Isolation**: Unprivileged containers prevent host system access

## Scripts

### proxmox-setup.sh (v2.4)
Runs on Proxmox host to create and configure containers:
- Auto-detects available container ID (100-999)
- Checks for existing containers by name (idempotent)
- Downloads Ubuntu 24.04 template from Proxmox repository
- Creates unprivileged container with nesting enabled
- Configures networking with DHCP on vmbr0 bridge
- Fetches SSH keys from GitHub
- Optionally configures GitHub CLI authentication via PAT
- Optionally installs Docker CE and Docker Compose v2
- Generates secure random passwords for root and dev users
- Downloads and executes full container-setup.sh from repository
- Displays container IP address after creation

Key features:
- `--docker` flag to install Docker CE and Docker Compose v2
- `--force` flag to recreate existing containers
- Automatic template detection from `pveam available`
- No fallback to older Ubuntu versions (fails if 24.04 unavailable)
- Downloads latest container-setup.sh from repository for consistency
- Password display only during setup (not stored)

### container-setup.sh
Standalone script for configuring any Ubuntu 24.04 container:
- Updates system packages
- Installs Python 3.12 and pip
- Installs Node.js LTS via nvm for the specified user
- Installs Claude Code CLI (@anthropic-ai/claude-code)
- Installs uv for Python package management
- Installs GitHub CLI (gh command) with optional PAT authentication
- Optionally installs Docker CE and Docker Compose v2 plugin
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
- Configures GitHub CLI authentication if token provided
- Checks if Docker is already installed, updates if present
- Only adds user to docker group if not already a member
- Preserves existing configurations

Can be run independently in Docker containers or existing VMs. Safe for updating existing containers with new features.

### proxmox-setup-ubuntu2504.sh (v3.0) - Improved Two-Phase Setup

Runs on Proxmox host to create Ubuntu Server 25.04 containers with enhanced control:

**Phase 1** - Container Creation + Dev User + SSH Access:
- Auto-detects available container ID (100-999)
- Checks for existing containers by name (idempotent)
- Downloads Ubuntu Server 25.04 template from Proxmox repository
- Creates unprivileged container with nesting enabled
- Configures networking with DHCP on vmbr0 bridge
- **Creates dev user with sudo access immediately**
- **Fetches and configures GitHub SSH keys in Phase 1**
- **Disables root SSH login for security**
- **Provides direct dev user SSH access** - no temporary root access
- Installs curl for Phase 2 script download

**Phase 2** - Manual Development Environment Setup:
- User SSH's into container as dev user using configured credentials/keys
- Runs provided curl command to execute container-setup-ubuntu2504.sh
- Complete development environment configuration (Python, Node.js, tools)
- Same functionality as Ubuntu 24.04 but with Ubuntu 25.04 packages

Key features:
- `--docker` flag to install Docker CE and Docker Compose v2
- `--force` flag to recreate existing containers
- Automatic Ubuntu Server 25.04 template detection from `pveam available`
- **Enhanced security** - dev user created immediately, no root SSH access
- **Improved UX** - SSH directly as dev user after Phase 1
- Clear separation between infrastructure (Phase 1) and application (Phase 2) setup

### container-setup-ubuntu2504.sh (v3.0) - Optimized with Native Packages

Standalone script for configuring any Ubuntu Server 25.04 container:

**Ubuntu 25.04-Specific Optimizations:**
- Uses native **APT packages** instead of external sources where possible
- **Node.js & npm**: Direct `apt install nodejs npm` (Node.js 20.18.1)
- **GitHub CLI**: Direct `apt install gh` from Ubuntu repos (faster than Ubuntu 24.04)
- **Faster installation** - no complex nvm setup needed
- **System-wide availability** - no user-specific shell configuration needed

**Phase 2 Focus** (assumes dev user exists from Phase 1):
- Verifies dev user exists (created in Phase 1)
- Updates system packages via apt
- Installs Python 3.13.3 and pip
- Installs Node.js 20.18.1 and npm via native packages
- Installs Claude Code CLI (@anthropic-ai/claude-code) via npm
- Installs uv for Python package management via curl
- Installs GitHub CLI (gh command) with optional PAT authentication
- Optionally installs Docker CE and Docker Compose v2 plugin
- Verifies SSH setup (already configured in Phase 1)
- Installs additional dev tools (vim, nano, htop, net-tools, etc.)

**Key Differences from Ubuntu 24.04:**
- **Assumes dev user exists** - validates instead of creating
- Uses native `apt install nodejs npm` instead of nvm
- Uses `apt install gh` instead of external repository setup
- **Enhanced security model** - no user creation in Phase 2
- Optimized for Ubuntu Server 25.04 package versions

Can be run independently in Docker containers or existing VMs, but designed to work with Phase 1 user setup.

## Design Decisions & Rationale

### Operating System Choice

**Dual Ubuntu Distribution Strategy**

**Ubuntu 24.04 LTS** - Stability & Enterprise Focus
- Python 3.12 available in main repositories (no PPA needed)
- 5-year support cycle (until April 2029)  
- Predictable package versions for reproducible builds
- Failing fast on unavailable templates prevents silent degradation
- **Best for**: Production environments, enterprise deployments, long-term projects

**Ubuntu Server 25.04** - Latest Features & Performance Focus
- Python 3.13.3 available in main repositories (latest features)
- Native Node.js 20.18.1 packages (faster installation than nvm)
- APT 3.0 with improved dependency resolver and colorful output
- 9-month support cycle (until January 2026)
- **Best for**: Development environments, latest features, cutting-edge development

### Package Management Strategy

**Ubuntu 24.04 LTS - External Sources Approach**
- **Node.js via nvm**: User-space installation, multiple versions, community best practices
- **GitHub CLI**: Via official GitHub repository for latest features
- **Python via system + uv**: System Python 3.12 + uv for fast package management

**Ubuntu Server 25.04 - Native Packages Approach**  
- **Node.js via apt**: System-wide installation, faster setup, native Ubuntu packages
- **GitHub CLI**: Via native Ubuntu repositories for better integration
- **Python via system + uv**: System Python 3.13.3 + uv for fast package management

**Common Strategy**
- System Python + uv for 10-100x faster package installation than pip
- Virtual environment support built-in
- Compatible with existing requirements.txt workflows
- Docker CE via official Docker repository (both distributions)

### Security Architecture
**Random Password Generation**
- 32 characters from /dev/urandom
- Forces secure credential storage practices
- Different passwords for root and dev users
- No default passwords that could be exploited

**SSH Key Management**
- GitHub as trusted source for public keys
- No password authentication if keys are present
- Supports multiple keys per user
- Keys fetched fresh during each setup

### Network Configuration
**DHCP-only approach**
- Zero network configuration required
- Works in 95% of environments
- Reduces setup complexity and errors
- Static IPs can be configured post-setup if needed

### Docker Installation Strategy (Optional)
**Official APT Repository Method**
- Uses Docker's official GPG key and APT repository for Ubuntu 24.04
- Installs Docker CE, Docker CLI, containerd, and plugins
- Docker Compose v2 installed as plugin (docker-compose-plugin)
- Invoked as `docker compose` (space, not hyphen) - modern approach
- User added to docker group for non-root container management
- Nesting already enabled in LXC for Docker compatibility

### Idempotency Implementation
- User existence checks before creation
- Package installation checks prevent duplicates
- Configuration file modifications are conditional
- SSH key deduplication prevents accumulation
- Docker installation checks prevent reinstallation
- Docker group membership verified before adding
- Service restarts only when necessary

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

### GitHub CLI Authentication
**Problem**: Need to authenticate GitHub CLI for API operations

**Solution**: Use Personal Access Token (PAT) during setup:
1. Create a PAT at https://github.com/settings/tokens
2. Required scopes: `repo` and `read:org`
3. Pass token during setup:
```bash
# During Proxmox container creation
./proxmox-setup.sh --github-token YOUR_PAT_HERE --github-user yourusername

# Or with container-setup.sh directly
GITHUB_TOKEN=YOUR_PAT_HERE ./container-setup.sh --github-user yourusername

# Or pass as parameter (less secure, visible in process list)
./container-setup.sh --github-token YOUR_PAT_HERE
```

**Security Notes**:
- Token is never logged or displayed
- Use environment variable method for better security
- Token enables gh CLI for operations like creating PRs, managing issues, etc.

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

## Performance Characteristics

### Installation Times (typical)
- **Container Creation**: 30-60 seconds
- **Base System Update**: 1-2 minutes
- **Python Installation**: 30 seconds
- **Node.js via nvm**: 1 minute
- **Tool Installation**: 2-3 minutes
- **Total Setup Time**: 5-7 minutes

### Resource Usage
- **Idle Memory**: ~200MB
- **Idle CPU**: <1%
- **Disk Space**: ~2GB base installation
- **Network Transfer**: ~500MB during setup

### Optimization Tips
- Use local APT mirror for faster package downloads
- Pre-download container templates to Proxmox storage
- Allocate containers on SSD storage for better I/O
- Use ZFS with lz4 compression for space efficiency

## Testing & Quality Assurance

### Automated Testing Checklist
When making changes, verify:
- [ ] **Container Creation**: Fresh container on clean Proxmox
- [ ] **Idempotency**: Running script twice produces same result
- [ ] **Force Recreation**: `--force` flag properly recreates
- [ ] **SSH Keys**: GitHub keys correctly fetched and installed
- [ ] **Password Generation**: Unique 32-char passwords displayed
- [ ] **Python Environment**: Python 3.12 and pip functional
- [ ] **Node.js Environment**: nvm, node, and npm working
- [ ] **Claude Code CLI**: Installed and accessible globally
- [ ] **uv Package Manager**: Fast Python package installation
- [ ] **GitHub CLI**: Authentication and operations work
- [ ] **User Permissions**: dev user has proper sudo access
- [ ] **SSH Access**: Remote connection successful
- [ ] **Dev Tools**: vim, nano, htop, curl, wget installed

### Integration Testing
```bash
# Test complete workflow
./proxmox-setup.sh --name test-container --github-user testuser
pct exec $(pct list | grep test-container | awk '{print $1}') -- su - dev -c "node --version"
pct exec $(pct list | grep test-container | awk '{print $1}') -- su - dev -c "python3 --version"
pct exec $(pct list | grep test-container | awk '{print $1}') -- su - dev -c "claude --version"
pct exec $(pct list | grep test-container | awk '{print $1}') -- su - dev -c "gh --version"
```

### Security Validation
```bash
# Verify unprivileged container
pct config <CTID> | grep unprivileged

# Check password complexity
pct exec <CTID> -- grep dev /etc/shadow

# Verify SSH key permissions
pct exec <CTID> -- ls -la /home/dev/.ssh/

# Test GitHub token not in logs
pct exec <CTID> -- journalctl | grep -i token
```

## Command Line Arguments

### proxmox-setup.sh
```bash
./proxmox-setup.sh [OPTIONS]
  --ctid ID           Container ID (auto-detect if not specified)
  --name NAME         Container name (default: devbox-YYMMDD)
  --memory MB         Memory in MB (default: 4096)
  --cores N           CPU cores (default: 2)
  --disk GB           Disk size in GB (default: 20)
  --storage NAME      Storage pool (default: local-zfs)
  --github-user NAME  GitHub username for SSH keys
  --github-token PAT  GitHub Personal Access Token for gh CLI authentication
  --docker            Install Docker CE and Docker Compose v2
  --force             Force recreate if container exists
```

### container-setup.sh
```bash
./container-setup.sh [OPTIONS]
  --user NAME         User to create (default: dev)
  --github-user NAME  GitHub username for SSH keys
  --github-token PAT  GitHub Personal Access Token for gh CLI authentication
  --docker            Install Docker CE and Docker Compose v2
  --no-ssh           Skip SSH server installation
```

## Best Practices for Extension

### Adding New Tools
```bash
# Example: Adding Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
```

### Custom Configuration Files
```bash
# Example: Adding custom .bashrc entries
cat >> ~/.bashrc << 'EOF'
# Custom aliases
alias ll='ls -alF'
alias gs='git status'
alias dc='docker-compose'
EOF
```

### Docker Inside LXC
```bash
# Enable nesting in container config
pct set <CTID> -features nesting=1

# Install Docker in container
curl -fsSL https://get.docker.com | sh
usermod -aG docker dev
```

### VS Code Remote Development
```bash
# Install code-server for browser-based VS Code
curl -fsSL https://code-server.dev/install.sh | sh
systemctl --user enable --now code-server
# Access at http://<container-ip>:8080
```

## Monitoring & Maintenance

### Health Checks
```bash
# System resource usage
pct exec <CTID> -- htop

# Disk usage
pct exec <CTID> -- df -h

# Network connectivity
pct exec <CTID> -- ping -c 4 8.8.8.8

# Service status
pct exec <CTID> -- systemctl status ssh
```

### Backup Strategy
```bash
# Backup container
vzdump <CTID> --storage local --compress zstd

# Restore container
pct restore <NEW_CTID> /var/lib/vz/dump/vzdump-lxc-<CTID>-*.tar.zst
```

### Update Procedures
```bash
# System updates
pct exec <CTID> -- apt update && apt upgrade -y

# Node.js update
pct exec <CTID> -- su - dev -c "nvm install --lts && nvm alias default lts/*"

# Python packages update
pct exec <CTID> -- su - dev -c "uv pip install --upgrade pip setuptools wheel"
```

## Version History

### v2.4 (Current)
- Added optional Docker CE and Docker Compose v2 support
- Docker installed via official APT repository method (not get.docker.com)
- Docker Compose v2 installed as plugin (docker-compose-plugin package)
- Idempotent Docker installation with update checking
- User automatically added to docker group
- Leverages existing nesting configuration for LXC compatibility

### v2.3
- Added GitHub CLI authentication support via Personal Access Tokens (PAT)
- Updated proxmox-setup.sh to download container-setup.sh from repository
- Secure token handling with environment variables
- Optional authentication with helpful guidance
- Enhanced error handling and validation

### v2.2
- Added Claude Code CLI installation (@anthropic-ai/claude-code)
- Installs globally via npm with automatic updates
- Improved nvm installation reliability

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

## AI Assistant Context

### When Working with This Codebase
- **Scripts are idempotent**: Running them multiple times is safe
- **Security is paramount**: Never expose tokens or passwords in logs
- **Minimal by design**: Resist adding unnecessary features
- **Test before committing**: All changes should be validated
- **Documentation matters**: Update CLAUDE.md with significant changes

### Common User Requests & Solutions

**"Make it work on Ubuntu 22.04"**
- Requires changing Python installation method (PPA needed)
- Template detection logic needs modification
- Not recommended - breaks consistency guarantee

**"Add Docker to the container"**
- Ensure nesting is enabled: `pct set <CTID> -features nesting=1`
- Use official Docker installation script
- Add dev user to docker group

**"Install specific Node.js version"**
- Use nvm commands after setup: `nvm install 18.17.0`
- Set as default: `nvm alias default 18.17.0`

**"Configure static IP"**
- Post-setup configuration in `/etc/netplan/` (Ubuntu 24.04)
- Restart networking after changes

### Script Modification Guidelines
- Maintain shellcheck compliance (no warnings)
- Preserve idempotency in all operations
- Test on fresh Proxmox installation
- Update version number in comments
- Document breaking changes clearly

### Important Reminders
- Do what has been asked; nothing more, nothing less
- NEVER create files unless they're absolutely necessary
- ALWAYS prefer editing existing files to creating new ones
- NEVER proactively create documentation unless requested
- Update CLAUDE.md after significant commits