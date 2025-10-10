# Debian Trixie + Nix Development Environment

**Reproducible development container with Python 3.13, Node.js 22.20.0, and modern tooling powered by Nix**

## Overview

This setup provides a **pure Debian Trixie (Debian 13 GA)** development environment with tools managed entirely by the **Nix package manager** for maximum reproducibility and consistency.

### What's Included

- **Base OS**: Debian Trixie (Debian 13 - GA/Stable)
- **Package Manager**: Nix (single-user mode)
- **Python**: 3.13 via Nix
- **Python Package Manager**: uv (10-100x faster than pip)
- **Node.js**: 22.20.0 via Nix
- **Claude Code CLI**: Anthropic's AI coding assistant
- **GitHub CLI**: Full GitHub integration (`gh` command)
- **atuin**: Modern shell history management
- **Development Tools**: vim, nano, htop, git, and more

### Why This Approach?

✅ **Reproducible**: Exact same environment on any machine
✅ **Pure Nix**: All dev tools via Nix (no apt package conflicts)
✅ **Modern Base**: Debian 13 stable foundation
✅ **Fast Python**: uv for ultra-fast package installation
✅ **Declarative**: Entire environment defined in `flake.nix`
✅ **Isolated**: Nix packages don't interfere with system

## Quick Start

### Prerequisites

- Docker Engine 20.10+ or Docker Desktop
- Git (to clone this repository)

### Build and Run

```bash
# Navigate to debian-trixie directory
cd debian-trixie

# Build the image
docker-compose build

# Run interactive container
docker-compose run --rm devbox

# Or run with GitHub integration
GITHUB_USER=yourusername docker-compose run --rm devbox
```

### With GitHub Authentication

```bash
# Set environment variables
export GITHUB_USER=yourusername
export GITHUB_TOKEN=ghp_your_token_here

# Run container with authentication
docker-compose run --rm devbox
```

## Usage

### Inside the Container

Once inside, all tools are immediately available:

```bash
# Check versions
python --version    # Python 3.13.0
node --version      # v22.20.0
npm --version       # Latest npm
uv --version        # uv package manager
claude --version    # Claude Code CLI
gh --version        # GitHub CLI
```

### Python Development with uv

**uv** is a blazing-fast Python package manager (10-100x faster than pip):

```bash
# Create virtual environment
uv venv

# Activate environment
source .venv/bin/activate

# Install packages (super fast!)
uv pip install django
uv pip install fastapi uvicorn

# Install from requirements.txt
uv pip sync requirements.txt

# Install with extras
uv pip install "flask[async]"

# Upgrade packages
uv pip install --upgrade django
```

### Node.js Development

```bash
# Initialize project
npm init -y

# Install packages
npm install express
npm install -D typescript @types/node

# Global tools
npm install -g typescript ts-node nodemon

# Run scripts
npm run dev
```

### Claude Code CLI

```bash
# Interactive coding assistant
claude chat

# Get help with code
claude "explain this function" < mycode.py

# Generate tests
claude "write unit tests" --file app.js

# Code review
claude "review for security" --dir ./src
```

### GitHub CLI Integration

```bash
# Check authentication
gh auth status

# Create repository
gh repo create my-project --public

# Work with pull requests
gh pr create --title "Add feature" --body "Description"
gh pr list
gh pr merge --auto

# Manage issues
gh issue create --title "Bug report"
gh issue list --label bug

# Run workflows
gh workflow run deploy.yml
gh run watch
```

### Shell History with atuin

```bash
# Search history interactively
# Press Ctrl+R to search

# Sync history across machines (optional)
atuin login
atuin sync
```

## File Structure

```
debian-trixie/
├── Dockerfile              # Container build definition
├── flake.nix              # Nix environment configuration
├── entrypoint.sh          # Environment activation script
├── docker-compose.yml     # Docker Compose configuration
├── .dockerignore          # Build optimization
├── workspace/             # Your code goes here (persistent)
└── README.md              # This file
```

## Environment Variables

### GitHub Integration

- **`GITHUB_USER`**: GitHub username for SSH key fetching
- **`GITHUB_TOKEN`**: Personal Access Token for GitHub CLI authentication

### Creating a GitHub Token

1. Go to [GitHub Settings → Tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Select scopes: `repo`, `read:org`, `workflow`
4. Copy the token (starts with `ghp_`)
5. Set as environment variable:
   ```bash
   export GITHUB_TOKEN=ghp_your_token_here
   ```

## Advanced Usage

### Persistent Workspace

The `workspace/` directory is mounted as a volume for persistent storage:

```bash
# Your code persists between container restarts
cd /workspace
git clone https://github.com/youruser/yourproject.git
cd yourproject
```

### Mount SSH Keys

Uncomment in `docker-compose.yml`:

```yaml
volumes:
  - ~/.ssh:/root/.ssh:ro
```

### Run Specific Commands

```bash
# Run a single command
docker-compose run --rm devbox python myscript.py

# Execute multiple commands
docker-compose run --rm devbox bash -c "python --version && node --version"
```

### Build Without Cache

```bash
# Fresh build
docker-compose build --no-cache
```

## Comparison with Other Approaches

### vs. Ubuntu Setup (from main lazyvimmer)

| Feature         | Ubuntu Script   | Debian + Nix          |
| --------------- | --------------- | --------------------- |
| Base OS         | Ubuntu 25.04    | Debian 13 Trixie      |
| Package Manager | apt + uv + nvm  | Nix                   |
| Reproducibility | Good            | Excellent             |
| Tool Versions   | System packages | Exact pins            |
| Rollback        | No              | Yes (Nix generations) |
| Isolation       | Limited         | Complete              |

### vs. NixOS (from nixos/ directory)

| Feature        | NixOS     | Debian + Nix  |
| -------------- | --------- | ------------- |
| Base           | NixOS     | Debian Trixie |
| Complexity     | Higher    | Lower         |
| Learning Curve | Steep     | Moderate      |
| Flexibility    | Very High | High          |
| Docker Support | Native    | Standard      |

## Troubleshooting

### Claude Code CLI not found

```bash
# Reinstall in the environment
npm install -g @anthropic-ai/claude-code

# Or rebuild environment
nix develop --rebuild
```

### Python/Node.js version incorrect

Check the versions in `flake.nix`:

- Python: `python314` or `python3`
- Node.js: `nodejs_22` or `nodejs-22_x`

Rebuild if changed:

```bash
docker-compose build --no-cache
```

### GitHub CLI authentication fails

```bash
# Check token format
echo $GITHUB_TOKEN | wc -c  # Should be 40+ characters

# Manual authentication
gh auth login --with-token < token.txt
```

### Nix commands not found

The entrypoint script should source Nix automatically. If issues persist:

```bash
# Manually source Nix profile
source /root/.nix-profile/etc/profile.d/nix.sh

# Verify
nix --version
```

### Container builds slowly

First build downloads Nix packages (~500MB). Subsequent builds are much faster due to Docker layer caching.

To speed up:

- Use Docker BuildKit: `DOCKER_BUILDKIT=1 docker-compose build`
- Use Nix binary cache (automatic)
- Increase Docker resources (CPU/Memory)

## Performance Notes

### Build Times

- **First build**: 5-10 minutes (downloads Nix packages)
- **Subsequent builds**: 30-60 seconds (layer cache)
- **Nix environment activation**: <1 second

### Resource Usage

- **Image size**: ~1.5-2GB (includes all tools)
- **Idle memory**: ~100MB
- **Active development**: 500MB-2GB (depends on workload)

### Optimization Tips

- Mount workspace as volume (avoid copying large codebases)
- Use `.dockerignore` to exclude unnecessary files
- Enable Docker BuildKit for parallel builds
- Use Nix binary cache (enabled by default)

## Development Workflow Examples

### Python Web App with FastAPI

```bash
# Create project
cd /workspace
mkdir myapp && cd myapp

# Install dependencies
uv venv
source .venv/bin/activate
uv pip install fastapi uvicorn

# Create app
cat > main.py << 'EOF'
from fastapi import FastAPI
app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World"}
EOF

# Run
uvicorn main:app --reload
```

### Node.js API with Express

```bash
# Initialize project
cd /workspace
mkdir api && cd api
npm init -y

# Install dependencies
npm install express

# Create server
cat > index.js << 'EOF'
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({ message: 'Hello World' });
});

app.listen(3000, () => {
  console.log('Server on port 3000');
});
EOF

# Run
node index.js
```

### Full-Stack Development

```bash
# Frontend (React)
npx create-react-app frontend
cd frontend
npm start

# Backend (Python)
cd ../backend
uv venv
source .venv/bin/activate
uv pip install flask flask-cors
python app.py
```

## Updating the Environment

### Update Nix Packages

```bash
# Inside container
nix flake update /workspace

# Rebuild environment
nix develop --rebuild
```

### Add New Tools

Edit `flake.nix` and add to `buildInputs`:

```nix
buildInputs = with pkgs; [
  # ... existing packages

  # Add new tools
  rust-analyzer
  gopls
  terraform
];
```

Then rebuild:

```bash
docker-compose build --no-cache
```

## Contributing

This is part of the [Lazyvimmer](https://github.com/TejGandham/lazyvimmer) project. Contributions welcome!

1. Fork the repository
2. Create your feature branch
3. Test in a fresh container
4. Submit a pull request

## Additional Resources

- [Nix Package Manager](https://nixos.org/manual/nix/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [uv Documentation](https://github.com/astral-sh/uv)
- [Claude Code CLI](https://docs.anthropic.com/claude-code/)
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [Debian Trixie Release](https://www.debian.org/releases/trixie/)

## License

MIT License - See main repository [LICENSE](../LICENSE) file for details.

---

**Built with ❤️ for developers who value reproducibility and modern tooling**
