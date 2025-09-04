# Lazyvimmer - Development Container Setup

<div align="center">

[![Ubuntu](https://img.shields.io/badge/Ubuntu_Server-25.04-E95420?style=flat&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Python](https://img.shields.io/badge/Python-3.13.3-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/)
[![Node.js](https://img.shields.io/badge/Node.js-LTS-339933?style=flat&logo=node.js&logoColor=white)](https://nodejs.org/)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE-E57000?style=flat&logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![Docker](https://img.shields.io/badge/Docker-Compatible-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)

**Production-ready scripts for creating minimal development containers on Proxmox**  
**Using Ubuntu Server 25.04 with modern Python 3.13.3 and Node.js**

</div>

## 🎯 Overview

Lazyvimmer provides idempotent, secure scripts for setting up development containers with modern tooling. Perfect for:
- **Rapid Development Environment Setup** - Get productive in minutes
- **CI/CD Pipelines** - Consistent build environments
- **Team Standardization** - Ensure everyone has the same tools
- **Learning & Experimentation** - Safe, isolated environments

## ✨ Key Features

### Core Components
- 🐧 **Ubuntu Server 25.04** - Latest interim release "Plucky Puffin"
- 🐍 **Python 3.13.3** - Latest stable Python with newest features
- 🟢 **Node.js 20.18.1** - LTS version via native apt packages
- 🤖 **Claude Code CLI** - Anthropic's official AI assistant CLI
- 📦 **uv Package Manager** - Ultra-fast Python package management
- 🔧 **GitHub CLI** - Full GitHub operations from command line
- 🐳 **Docker Support** (Optional) - Docker CE with Docker Compose v2
- 🔐 **SSH Integration** - Secure access with GitHub key authentication
- 🛡️ **Security First** - Unprivileged containers with random passwords

### Design Principles
- **Idempotent** - Safe to run multiple times without side effects
- **Minimal** - Only essential tools, extend as needed
- **Secure** - Random passwords, unprivileged containers, SSH keys
- **Flexible** - Works on Proxmox, Docker, or existing VMs
- **Fast** - Optimized installation order and caching

## 🚀 Quick Start

### Prerequisites
- **For Proxmox**: Proxmox VE 7.0+ with internet access
- **For Docker**: Docker Engine 20.10+ or Docker Desktop
- **For Standalone**: Ubuntu Server 25.04 system

### 🔨 Quick Utilities

#### Create Git Patch from Staged Changes
```bash
# Create a patch file from your staged git changes
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/create_patch.sh | bash

# Or with wget
wget -qO- https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/create_patch.sh | bash

# Or with wcurl (wget-like syntax for curl)
wcurl https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/create_patch.sh | bash
```

## 📖 Usage

### 1️⃣ Proxmox Container Setup

> **Best for**: Development environments, latest features, cutting-edge Python

**Two-phase setup for better control:**

**Phase 1** - Create container with SSH access:
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

# With Docker support
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/proxmox-setup.sh | bash -s -- \
  --name mydev \
  --github-user yourusername \
  --docker
```

**Phase 2** - SSH into container and run setup:
```bash
# SSH into the container as dev user (get IP from Phase 1 output)
ssh dev@<CONTAINER_IP>

# Run the application setup script
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | bash -s -- \
  --user dev \
  --github-user yourusername

# With GitHub CLI authentication
GITHUB_TOKEN="your_token" \
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | bash -s -- \
  --user dev \
  --github-user yourusername \
  --github-token "$GITHUB_TOKEN"

# With Docker support
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | bash -s -- \
  --user dev \
  --github-user yourusername \
  --docker
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
- `--docker` - Install Docker CE and Docker Compose v2
- `--force` - Force recreate if container with same name exists

**What you get:**
- ✅ **Ubuntu Server 25.04** - Latest interim release with 9-month support
- ✅ **Secure dev user** - Created in Phase 1 with GitHub SSH keys
- ✅ **Direct SSH access** - No temporary root access needed
- ✅ **Python 3.13.3** - Latest stable Python with newest features
- ✅ **Node.js 20.18.1** - Native apt package (faster installation)
- ✅ **APT 3.0** - Improved dependency resolver and colorful output
- ✅ **Two-phase setup** - Better control and security

### 2️⃣ Standalone Container Setup

> **Best for**: Docker environments, existing VMs, cloud instances

Run inside any Ubuntu Server 25.04 container:

```bash
# Inside any Ubuntu Server 25.04 container
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | sudo bash

# With GitHub SSH keys
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | sudo bash -s -- \
  --github-user yourusername

# With GitHub CLI authentication
export GITHUB_TOKEN="your_personal_access_token"
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | \
  sudo GITHUB_TOKEN="$GITHUB_TOKEN" bash -s -- --github-user yourusername

# With Docker support
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | \
  sudo bash -s -- --docker
```

#### Ubuntu Server 25.04

Run inside any Ubuntu Server 25.04 container:

```bash
# Inside any Ubuntu Server 25.04 container
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup-ubuntu2504.sh | sudo bash

# With GitHub SSH keys
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup-ubuntu2504.sh | sudo bash -s -- \
  --github-user yourusername

# With GitHub CLI authentication
export GITHUB_TOKEN="your_personal_access_token"
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup-ubuntu2504.sh | \
  sudo GITHUB_TOKEN="$GITHUB_TOKEN" bash -s -- --github-user yourusername

# With Docker support
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup-ubuntu2504.sh | \
  sudo bash -s -- --docker
```

### Options for container-setup.sh

- `--user NAME` - User to create (default: dev)
- `--github-user NAME` - GitHub username for SSH keys
- `--github-token PAT` - GitHub Personal Access Token for gh CLI authentication
- `--docker` - Install Docker CE and Docker Compose v2
- `--no-ssh` - Skip SSH server installation

## 🔑 Accessing Your Container

### Finding Your Container

**On Proxmox:**
```bash
# List all containers
pct list

# Get container IP
pct exec <CTID> -- ip addr show | grep "inet "
```

**On Docker:**
```bash
# List running containers
docker ps

# Get container IP
docker inspect <container-name> | grep IPAddress
```

### SSH Access

```bash
ssh dev@<container-ip>
# Use the password displayed during setup
```

> ⚠️ **Important**: Save the generated passwords immediately! They are:
> - Cryptographically secure (32 characters)
> - Only displayed once during setup
> - Different for root and dev users

## 🛠️ Tool Usage

### Node.js Development

Node.js 20.18.1 is installed via native apt packages:

```bash
# Check version
node --version             # Should show v20.18.1
npm --version             # Check npm version

# Package management
npm init -y                # Initialize new project
npm install express        # Install packages
npm run dev               # Run development scripts

# Global tools
npm install -g typescript  # TypeScript compiler
npm install -g nodemon     # Auto-restart on changes
```

### Python Development

Python 3.13.3 with uv for ultra-fast package management:

```bash
# Using uv (recommended - 10-100x faster than pip)
uv venv                    # Create virtual environment
source .venv/bin/activate  # Activate environment
uv pip install django      # Install packages
uv pip sync requirements.txt # Install from requirements

# Traditional approach
python3 --version          # Check version
python3 -m venv myenv      # Create venv
pip3 install --upgrade pip # Update pip
pip3 install -r requirements.txt
```

### Claude Code CLI

Anthropic's AI assistant for coding tasks:

```bash
# Basic usage
claude --help              # Show all commands
claude --version           # Check version
claude chat               # Start interactive session

# Common workflows
claude "explain this code" < script.py
claude "write unit tests" --file app.js
claude "review for security issues" --dir ./src
```

### Docker Development (Optional)

When installed with `--docker` flag, Docker CE and Docker Compose v2 are available:

```bash
# Docker basics
docker --version              # Check Docker version
docker run hello-world        # Test Docker installation
docker ps                     # List running containers
docker images                # List available images

# Docker Compose v2 (note: space, not hyphen)
docker compose version        # Check Compose version
docker compose up            # Start services defined in docker-compose.yml
docker compose down          # Stop and remove containers
docker compose logs          # View logs from services

# Building and running containers
docker build -t myapp .      # Build image from Dockerfile
docker run -d -p 8080:80 myapp  # Run container in background
docker exec -it <container> bash # Enter running container

# Container management
docker stop <container>      # Stop a running container
docker rm <container>        # Remove stopped container
docker rmi <image>          # Remove an image

# Note: User 'dev' needs to logout/login for docker group to take effect
```

### GitHub CLI Integration

Full GitHub workflow automation from the command line:

```bash
# Authentication check
gh auth status

# Repository operations
gh repo create my-project --public
gh repo clone owner/repo
gh repo view --web

# Pull request workflow
gh pr create --title "Add feature" --body "Description"
gh pr list --state open
gh pr review --approve
gh pr merge --auto

# Issue management
gh issue create --title "Bug report"
gh issue list --label bug
gh issue close 123

# GitHub Actions
gh run list --workflow=ci.yml
gh run watch
gh workflow run deploy.yml
```

#### Setting up GitHub Authentication

1. **Create a Personal Access Token**:
   - Go to [GitHub Settings → Tokens](https://github.com/settings/tokens)
   - Click "Generate new token (classic)"
   - Required scopes: `repo`, `read:org`, `workflow` (for Actions)
   - Save the token securely

2. **Pass during setup**:
   ```bash
   # Environment variable (recommended)
   export GITHUB_TOKEN="ghp_your_token_here"
   ./container-setup.sh --github-user yourusername
   
   # Or as parameter (visible in process list)
   ./container-setup.sh --github-token "ghp_your_token_here"
   ```

3. **Manual authentication** (after setup):
   ```bash
   gh auth login
   # Follow interactive prompts
   ```

## 🔧 Advanced Configuration

### Custom Resource Allocation

```bash
# High-performance development machine
./proxmox-setup.sh \
  --name power-dev \
  --memory 16384 \
  --cores 8 \
  --disk 100 \
  --storage nvme-pool

# Minimal testing environment
./proxmox-setup.sh \
  --name test-env \
  --memory 2048 \
  --cores 1 \
  --disk 10
```

### Updating Existing Containers

The scripts are idempotent - run them again to update:

```bash
# From inside container
curl -fsSL https://raw.githubusercontent.com/TejGandham/lazyvimmer/main/container-setup.sh | \
  sudo bash -s -- --github-user yourusername

# From Proxmox host
pct push <CTID> container-setup.sh /tmp/setup.sh
pct exec <CTID> -- bash /tmp/setup.sh --github-user yourusername
```

### Docker Compose Integration

```yaml
# docker-compose.yml
version: '3.8'
services:
  devbox:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - ./workspace:/home/dev/workspace
      - ~/.ssh:/home/dev/.ssh:ro
    ports:
      - "2222:22"
    environment:
      - GITHUB_USER=yourusername
```

```dockerfile
# Dockerfile
FROM ubuntu:25.04
COPY container-setup.sh /tmp/
RUN bash /tmp/container-setup.sh --user dev --no-ssh
USER dev
WORKDIR /home/dev
```

## 🔍 Troubleshooting

### Common Issues

<details>
<summary><b>Container creation fails: "Template not found"</b></summary>

```bash
# Update Proxmox template list
pveam update

# Verify Ubuntu Server 25.04 is available
pveam available | grep ubuntu-25

# Manually download if needed
pveam download local ubuntu-25.04-standard_25.04-1_amd64.tar.zst
```
</details>

<details>
<summary><b>SSH connection refused</b></summary>

```bash
# Check if SSH service is running
pct exec <CTID> -- systemctl status ssh

# Restart SSH if needed
pct exec <CTID> -- systemctl restart ssh

# Check firewall rules
pct exec <CTID> -- ufw status
```
</details>

<details>
<summary><b>Node.js/npm not found</b></summary>

```bash
# Node.js is installed system-wide via apt
# Check installation
which node
node --version

# If not found, reinstall
sudo apt update && sudo apt install nodejs npm -y
```
</details>

<details>
<summary><b>GitHub CLI authentication fails</b></summary>

```bash
# Check token permissions
gh auth status

# Re-authenticate interactively
gh auth login

# Verify token scopes
gh api user -H "Accept: application/vnd.github.v3+json"
```
</details>

### Performance Optimization

**For Proxmox:**
- Use SSD storage for better I/O performance
- Enable KSM (Kernel Samepage Merging) for memory deduplication
- Consider using ZFS with compression for storage efficiency

**For Containers:**
- Mount development directories as volumes to preserve work
- Use `--cores` matching your workload (compilation needs more cores)
- Allocate extra memory for memory-intensive tasks (building, testing)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes thoroughly
4. Update documentation as needed
5. Submit a pull request

### Development Setup

```bash
# Clone the repo
git clone https://github.com/TejGandham/lazyvimmer.git
cd lazyvimmer

# Test in a local container
docker build -t lazyvimmer-test .
docker run -it lazyvimmer-test

# Run shellcheck for script validation
shellcheck *.sh
```

## 📚 Additional Resources

- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Ubuntu Server 25.04 Release Notes](https://discourse.ubuntu.com/t/plucky-puffin-release-notes/)
- [Node.js Documentation](https://nodejs.org/docs/)
- [uv Python Package Manager](https://github.com/astral-sh/uv)
- [Claude Code Documentation](https://docs.anthropic.com/claude-code/)
- [GitHub CLI Manual](https://cli.github.com/manual/)

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Proxmox team for excellent virtualization platform
- Ubuntu team for innovative interim releases
- Node.js and Python communities
- Anthropic for Claude Code CLI
- GitHub for gh CLI tool

---

<div align="center">

**Built with ❤️ for developers who value simplicity and efficiency**

[Report Bug](https://github.com/TejGandham/lazyvimmer/issues) · [Request Feature](https://github.com/TejGandham/lazyvimmer/issues) · [Documentation](https://github.com/TejGandham/lazyvimmer/wiki)

</div>