# Devbox Setup Scripts

Minimal scripts for setting up development containers with Python 3.12 and Node.js LTS.

## Features

- Ubuntu 24.04 LTS base
- Python 3.12 (from Ubuntu repos)
- Node.js LTS via nvm (v0.40.3)
- SSH access with GitHub key support
- Unprivileged containers on Proxmox

## Usage

### Proxmox Container Setup

Run on your Proxmox host to create a new container:

```bash
# Quick setup with defaults
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox-setup.sh | bash

# With custom options
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox-setup.sh | bash -s -- \
  --name mydev \
  --memory 8192 \
  --cores 4 \
  --disk 50 \
  --github-user yourusername
```

### Options for proxmox-setup.sh

- `--ctid ID` - Container ID (auto-detect if not specified)
- `--name NAME` - Container name (default: devbox-YYMMDD)
- `--memory MB` - Memory in MB (default: 4096)
- `--cores N` - CPU cores (default: 2)
- `--disk GB` - Disk size in GB (default: 20)
- `--storage NAME` - Storage pool (default: local-zfs)
- `--github-user NAME` - GitHub username for SSH keys
- `--force` - Force recreate if container with same name exists

### Standalone Container Setup

For existing containers or Docker environments:

```bash
# Inside any Ubuntu 24.04 container
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | sudo bash

# With GitHub SSH keys
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | sudo bash -s -- \
  --github-user yourusername
```

### Options for container-setup.sh

- `--user NAME` - User to create (default: dev)
- `--github-user NAME` - GitHub username for SSH keys
- `--no-ssh` - Skip SSH server installation

## Access

After setup, SSH into your container:

```bash
ssh dev@<container-ip>
# Password will be displayed during setup (randomly generated)
```

The script generates secure random passwords for both root and dev users. 
Save these passwords securely as they are only shown once during setup.

## Node.js Usage

Node.js is installed via nvm for the dev user:

```bash
# As dev user
nvm list         # List installed versions
nvm use lts/*    # Use latest LTS
node --version   # Check Node.js version
npm --version    # Check npm version
```

## Python Usage

Python 3.12 is available system-wide:

```bash
python3 --version
pip3 install <package>
python3 -m venv myenv
```