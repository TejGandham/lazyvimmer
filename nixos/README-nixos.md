# NixOS Development Environment

This directory contains NixOS equivalents to the Ubuntu `container-setup.sh` script, providing the exact same development environment using declarative configuration.

## Overview

The NixOS configuration provides:
- **Python 3.13** with pip, venv, and development packages
- **Node.js 20.x** with npm 
- **Claude Code CLI** (@anthropic-ai/claude-code)
- **uv** - Fast Python package manager
- **GitHub CLI** with optional authentication
- **atuin** - Shell history tool
- **Development tools** - vim, nano, htop, net-tools, etc.
- **Optional Docker** - Docker CE with Docker Compose v2
- **'dev' user** with sudo access and SSH key support
- **Locale configuration** - en_US.UTF-8
- **Security** - SSH keys from GitHub, no root login

## Usage Options

### Option 1: Nix Flake (Recommended)

For development environments and containers:

```bash
# Enter development shell with all tools
nix develop

# Or run directly from GitHub
nix develop github:TejGandham/lazyvimmer#nixos

# Build NixOS container configuration
nix build .#nixosConfigurations.devcontainer.config.system.build.toplevel
```

### Option 2: Traditional NixOS Configuration

For full system installations:

```bash
# Copy configuration
sudo cp nixos/configuration.nix /etc/nixos/

# Apply configuration
sudo nixos-rebuild switch
```

### Option 3: NixOS Container/LXC

Create NixOS containers equivalent to Proxmox LXC setup:

```bash
# Build container
sudo nixos-container create devcontainer --flake .#devcontainer

# Start container
sudo nixos-container start devcontainer

# Login to container
sudo nixos-container login devcontainer
```

## Configuration

### GitHub Authentication

Set environment variables for GitHub integration:

```bash
# For SSH key fetching
export GITHUB_USERNAME="yourusername"

# For GitHub CLI authentication  
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"

# Apply configuration
nix develop  # or nixos-rebuild switch
```

### Docker Support

Docker is enabled by default in the configurations. To disable:

```nix
# In configuration.nix
virtualisation.docker.enable = false;
```

### Custom SSH Keys

Add SSH keys manually in `configuration.nix`:

```nix
users.users.dev = {
  openssh.authorizedKeys.keys = [
    "ssh-rsa AAAA... your-key-here"
    "ssh-ed25519 AAAA... another-key"
  ];
};
```

## Files Description

### `flake.nix`
Main flake configuration providing:
- **devShells.default** - Development environment with all tools
- **nixosModules.default** - Reusable NixOS module
- **nixosConfigurations.devcontainer** - Complete container configuration

### `configuration.nix`
Standalone NixOS configuration file equivalent to the Ubuntu setup script. Can be used directly in `/etc/nixos/configuration.nix` or imported.

## Equivalent Functionality

| Ubuntu Script Feature | NixOS Implementation |
|----------------------|---------------------|
| `apt update && apt upgrade` | Automatic with `nixos-rebuild` |
| `apt install python3 python3-pip` | `python313` + `python313Packages.pip` |
| `apt install nodejs npm` | `nodejs_20` package |
| `npm install -g @anthropic-ai/claude-code` | Automatic in shellHook/activation |
| `curl uv install` | `uv` package |
| `curl atuin install` | `atuin` package |
| `apt install gh` | `gh` package |
| User creation + sudo | `users.users.dev` + `security.sudo` |
| SSH key from GitHub | `fetchGitHubKeys` function |
| Docker installation | `virtualisation.docker.enable` |
| .bashrc modifications | `programs.bash.shellInit` |
| Locale configuration | `i18n.defaultLocale` |

## Advantages of NixOS Approach

1. **Declarative** - Entire environment defined in code
2. **Reproducible** - Same result on any machine
3. **Atomic** - Updates are atomic, can rollback
4. **Composable** - Easy to extend and modify
5. **Efficient** - Binary caches, no compilation needed
6. **Secure** - Immutable system, clear dependencies

## Development Workflow

### Quick Start
```bash
# Clone repository
git clone https://github.com/TejGandham/lazyvimmer.git
cd lazyvimmer

# Enter development environment
nix develop ./nixos

# Verify tools
python --version    # Python 3.13.x
node --version      # v20.x.x
claude --version    # Claude Code CLI
gh --version        # GitHub CLI
```

### Container Development
```bash
# Create development container
sudo nixos-container create mydev --flake ./nixos#devcontainer

# Start and enter
sudo nixos-container start mydev
sudo nixos-container root-login mydev

# Switch to dev user
su - dev
```

### System Installation
```bash
# For new NixOS systems
sudo cp nixos/configuration.nix /etc/nixos/
sudo nixos-rebuild switch

# For existing systems (import)
# Add to /etc/nixos/configuration.nix:
imports = [ ./path/to/nixos/configuration.nix ];
```

## Customization

### Adding New Packages

In `flake.nix`:
```nix
buildInputs = with pkgs; [
  # existing packages...
  rust-analyzer
  gopls
  terraform
];
```

In `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  # existing packages...
  rust-analyzer
  gopls
  terraform
];
```

### Environment Variables

```nix
environment.variables = {
  EDITOR = "vim";
  BROWSER = "firefox";
  CUSTOM_VAR = "value";
};
```

### Shell Aliases

```nix
programs.bash.shellAliases = {
  ll = "ls -alF";
  gc = "git commit";
  tf = "terraform";
};
```

## Troubleshooting

### Claude Code CLI Not Found
```bash
# Reinstall in development shell
npm install -g @anthropic-ai/claude-code

# Or rebuild environment
nix develop --rebuild
```

### GitHub CLI Authentication Issues
```bash
# Check token format
echo $GITHUB_TOKEN | wc -c  # Should be 41+ characters

# Manual authentication
gh auth login --with-token < token.txt
```

### Docker Permission Issues
```bash
# Verify user in docker group
groups $USER | grep docker

# If missing, rebuild system
sudo nixos-rebuild switch
```

### SSH Key Issues
```bash
# Check if keys were fetched
cat ~/.ssh/authorized_keys

# Manual key addition
echo "ssh-rsa AAAA..." >> ~/.ssh/authorized_keys
```

## Performance Notes

- **Cold start**: First build downloads packages (~500MB)
- **Warm start**: Subsequent builds are near-instant
- **Binary cache**: Most packages available pre-built
- **Garbage collection**: Automatic cleanup of old generations

## Migration from Ubuntu

To migrate from Ubuntu container-setup.sh:

1. **Environment**: Use `nix develop ./nixos` for equivalent shell
2. **System**: Use `nixos/configuration.nix` for equivalent system
3. **Container**: Use flake container configuration
4. **Docker**: Same commands work (`docker`, `docker compose`)
5. **SSH**: Same key management, better declarative config
6. **Updates**: `nixos-rebuild switch` instead of `apt upgrade`

## Security Features

- **Immutable system** - Root filesystem read-only
- **User isolation** - Non-privileged dev user
- **SSH hardening** - Key-only authentication
- **Firewall** - Only SSH port open by default
- **Reproducible** - No drift from initial state
- **Atomic updates** - Can't break system during updates

## Contributing

To extend this configuration:

1. Fork the repository
2. Modify `nixos/flake.nix` or `nixos/configuration.nix`
3. Test with `nix flake check`
4. Submit pull request

For Ubuntu equivalent features, ensure the NixOS configuration provides the same functionality as the original `container-setup.sh` script.