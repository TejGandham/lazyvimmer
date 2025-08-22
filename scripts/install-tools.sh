#!/usr/bin/env bash
set -euo pipefail

# Install development tools: Lazygit, Node.js, Claude Code, uv

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

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
    log_info "Installing Node.js LTS..."
    
    # Download and run NodeSource setup script
    curl -fsSL https://deb.nodesource.com/setup_lts.x -o /tmp/nodesource_setup.sh
    
    if [ "$EUID" -eq 0 ]; then
        bash /tmp/nodesource_setup.sh
        apt-get update -y
        apt-get install -y nodejs
    else
        sudo bash /tmp/nodesource_setup.sh
        sudo apt-get update -y
        sudo apt-get install -y nodejs
    fi
    
    rm -f /tmp/nodesource_setup.sh
    
    # Verify Node.js installation
    if node --version && npm --version; then
        log_info "Node.js installed successfully"
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
    
    if command -v claude-code &>/dev/null; then
        log_info "Claude Code CLI installed successfully"
    else
        log_error "Claude Code CLI installation verification failed"
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