# Devbox Setup Scripts

Minimal scripts for setting up development containers with Python 3.12 and Node.js LTS.

## Features

- Ubuntu 24.04 LTS base
- Python 3.12 (from Ubuntu repos)
- Node.js LTS via nvm (v0.40.3)
- Claude Code CLI (Anthropic's official CLI)
- uv Python package manager
- GitHub CLI (gh command) with optional authentication
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

# With GitHub CLI authentication (recommended for development)
export GITHUB_TOKEN="your_personal_access_token"
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox-setup.sh | bash -s -- \
  --name mydev \
  --github-user yourusername \
  --github-token "$GITHUB_TOKEN"
```

### Options for proxmox-setup.sh

- `--ctid ID` - Container ID (auto-detect if not specified)
- `--name NAME` - Container name (default: devbox-YYMMDD)
- `--memory MB` - Memory in MB (default: 4096)
- `--cores N` - CPU cores (default: 2)
- `--disk GB` - Disk size in GB (default: 20)
- `--storage NAME` - Storage pool (default: local-zfs)
- `--github-user NAME` - GitHub username for SSH keys
- `--github-token PAT` - GitHub Personal Access Token for gh CLI authentication
- `--force` - Force recreate if container with same name exists

### Standalone Container Setup

For existing containers or Docker environments:

```bash
# Inside any Ubuntu 24.04 container
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | sudo bash

# With GitHub SSH keys
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | sudo bash -s -- \
  --github-user yourusername

# With GitHub CLI authentication
export GITHUB_TOKEN="your_personal_access_token"
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | \
  sudo GITHUB_TOKEN="$GITHUB_TOKEN" bash -s -- --github-user yourusername
```

### Options for container-setup.sh

- `--user NAME` - User to create (default: dev)
- `--github-user NAME` - GitHub username for SSH keys
- `--github-token PAT` - GitHub Personal Access Token for gh CLI authentication
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

## Claude Code CLI

Claude Code is installed globally and available as:

```bash
claude --help          # Show help
claude --version       # Check version
```

## GitHub CLI

GitHub CLI is installed and can be authenticated with a Personal Access Token:

```bash
# Check authentication status
gh auth status

# Use gh for GitHub operations (if authenticated)
gh repo clone owner/repo
gh pr create
gh issue list
```

To create a Personal Access Token:
1. Visit https://github.com/settings/tokens
2. Create a token with `repo` and `read:org` scopes
3. Pass it during setup with `--github-token` parameter