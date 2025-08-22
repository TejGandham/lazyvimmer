#!/usr/bin/env bash
set -euo pipefail

# Install development tools: Lazygit, Node.js, Claude Code, uv

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }
log_warn() { echo "[WARN] $1" >&2; }

# Install Lazygit
install_lazygit() {
    local LAZYGIT_VERSION="${LAZYGIT_VERSION:-0.44.1}"
    
    log_info "Installing Lazygit ${LAZYGIT_VERSION}..."
    
    # Detect architecture
    ARCH="$(dpkg --print-architecture)"
    case "$ARCH" in
        amd64)
            REL_ARCH="Linux_x86_64"
            ;;
        arm64)
            REL_ARCH="Linux_arm64"
            ;;
        *)
            log_error "Unsupported architecture for Lazygit: $ARCH"
            return 1
            ;;
    esac
    
    # Download and install
    local URL="https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_${REL_ARCH}.tar.gz"
    
    if curl -fsSL -o /tmp/lazygit.tgz "$URL"; then
        if [ "$EUID" -eq 0 ]; then
            tar -xzf /tmp/lazygit.tgz -C /usr/local/bin lazygit
        else
            sudo tar -xzf /tmp/lazygit.tgz -C /usr/local/bin lazygit
        fi
        rm -f /tmp/lazygit.tgz
        
        if lazygit --version; then
            log_info "Lazygit installed successfully"
        else
            log_error "Lazygit installation verification failed"
            return 1
        fi
    else
        log_error "Failed to download Lazygit"
        return 1
    fi
}

# Install Node.js LTS and Claude Code
install_nodejs_claude() {
    log_info "Installing Node.js 22 LTS..."
    
    # Install prerequisites for NodeSource repository
    if [ "$EUID" -eq 0 ]; then
        apt-get update -y
        apt-get install -y ca-certificates curl gnupg
        mkdir -p /etc/apt/keyrings
    else
        sudo apt-get update -y
        sudo apt-get install -y ca-certificates curl gnupg
        sudo mkdir -p /etc/apt/keyrings
    fi
    
    # Add NodeSource GPG key and repository for Node.js 22
    log_info "Adding NodeSource repository for Node.js 22..."
    if [ "$EUID" -eq 0 ]; then
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
        NODE_MAJOR=22
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
        apt-get update -y
        apt-get install -y nodejs
    else
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
        NODE_MAJOR=22
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
        sudo apt-get update -y
        sudo apt-get install -y nodejs
    fi
    
    # Verify Node.js installation
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        NODE_VERSION=$(node --version)
        NPM_VERSION=$(npm --version)
        log_info "Node.js installed successfully: node $NODE_VERSION, npm $NPM_VERSION"
    else
        log_error "Node.js installation verification failed"
        return 1
    fi
    
    # Install Claude Code CLI
    log_info "Installing Claude Code CLI..."
    if [ "$EUID" -eq 0 ]; then
        npm install -g @anthropic-ai/claude-code
    else
        sudo npm install -g @anthropic-ai/claude-code
    fi
    
    # Find where npm installed global packages
    NPM_PREFIX=$(npm config get prefix)
    log_info "NPM global prefix: $NPM_PREFIX"
    
    # Add npm bin to PATH if not already there
    export PATH="$NPM_PREFIX/bin:$PATH"
    
    # Verify Claude Code installation - check multiple possible command names
    if command -v claude-code >/dev/null 2>&1; then
        CLAUDE_VERSION=$(claude-code --version 2>/dev/null || echo "version unknown")
        log_info "Claude Code CLI installed successfully: $CLAUDE_VERSION"
    elif command -v claude >/dev/null 2>&1; then
        CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "version unknown")
        log_info "Claude Code CLI installed successfully (as 'claude'): $CLAUDE_VERSION"
    elif [ -f "$NPM_PREFIX/bin/claude-code" ]; then
        log_info "Claude Code CLI installed at $NPM_PREFIX/bin/claude-code"
        log_info "Add $NPM_PREFIX/bin to your PATH to use it"
    elif [ -f "$NPM_PREFIX/bin/claude" ]; then
        log_info "Claude Code CLI installed at $NPM_PREFIX/bin/claude"
        log_info "Add $NPM_PREFIX/bin to your PATH to use it"
    else
        log_error "Claude Code CLI installation verification failed"
        log_warn "Package installed but command not found in PATH"
        log_warn "Try running: npm list -g @anthropic-ai/claude-code"
        log_warn "You may need to add npm bin directory to PATH"
        return 1
    fi
}

# Install uv (Python package manager)
install_uv() {
    log_info "Installing uv (Python package manager)..."
    
    # Download and run the official installer
    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
        log_info "uv installed successfully"
        
        # Add to PATH for current session if not already there
        if [ -f "$HOME/.cargo/bin/uv" ] && ! command -v uv &>/dev/null; then
            export PATH="$HOME/.cargo/bin:$PATH"
            log_info "Added uv to PATH for current session"
            log_info "Note: Add 'export PATH=\"\$HOME/.cargo/bin:\$PATH\"' to your shell config"
        fi
    else
        log_error "Failed to install uv"
        return 1
    fi
}

# Main installation
main() {
    log_info "Installing development tools..."
    
    # Install each tool
    install_lazygit || log_error "Lazygit installation failed, continuing..."
    install_nodejs_claude || log_error "Node.js/Claude Code installation failed, continuing..."
    install_uv || log_error "uv installation failed, continuing..."
    
    log_info "Development tools installation complete"
}

# Run main installation
main