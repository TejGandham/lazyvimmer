#!/usr/bin/env bash
set -euo pipefail

# Lazyvim Devbox Setup Script
# Works for both Docker containers and Proxmox CTs/VMs

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default configuration
INSTALL_USER="${INSTALL_USER:-$USER}"
CREATE_USER="${CREATE_USER:-false}"
SETUP_SSH="${SETUP_SSH:-false}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
SKIP_LAZYVIM="${SKIP_LAZYVIM:-false}"
UNATTENDED="${UNATTENDED:-true}"
CT_NAME="${CT_NAME:-}"
GITHUB_RAW_URL="${GITHUB_RAW_URL:-https://raw.githubusercontent.com/TejGandham/lazyvimmer/main}"

# Script directory detection
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Running from curl, use GitHub
    SCRIPT_DIR=""
    USE_GITHUB=true
fi

# Function to source or download and execute scripts
run_script() {
    local script_name="$1"
    shift
    
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$script_name" ]; then
        log_info "Running local $script_name"
        source "$SCRIPT_DIR/$script_name" "$@"
    else
        log_info "Downloading and running $script_name"
        bash <(curl -fsSL "$GITHUB_RAW_URL/$script_name") "$@"
    fi
}

# Function to download file
download_file() {
    local url="$1"
    local dest="$2"
    
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/${url#*/}" ]; then
        cp "$SCRIPT_DIR/${url#*/}" "$dest"
    else
        curl -fsSL "$GITHUB_RAW_URL/$url" -o "$dest"
    fi
}

# Detect environment
detect_environment() {
    if [ -f /.dockerenv ]; then
        echo "docker"
    elif [ -f /run/systemd/container ] || systemd-detect-virt -c &>/dev/null; then
        echo "container"
    elif systemd-detect-virt -v &>/dev/null; then
        echo "vm"
    else
        echo "bare"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            INSTALL_USER="$2"
            shift 2
            ;;
        --create-user)
            CREATE_USER=true
            INSTALL_USER="${2:-dev}"
            shift 2
            ;;
        --setup-ssh)
            SETUP_SSH=true
            shift
            ;;
        --workspace)
            WORKSPACE_DIR="$2"
            shift 2
            ;;
        --skip-lazyvim)
            SKIP_LAZYVIM=true
            shift
            ;;
        --unattended)
            # Unattended mode - skip all prompts, use defaults
            UNATTENDED=true
            shift
            ;;
        --name)
            CT_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --user USER         Install for specified user (default: current user)"
            echo "  --create-user USER  Create new user and install (default: dev)"
            echo "  --setup-ssh         Configure SSH server"
            echo "  --workspace DIR     Set workspace directory (default: /workspace)"
            echo "  --skip-lazyvim      Skip LazyVim installation"
            echo "  --unattended        Run in unattended mode (default: true)"
            echo "  --name NAME         Container name (for Proxmox CT creation)"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Main installation
main() {
    local env_type=$(detect_environment)
    
    log_info "Detected environment: $env_type"
    log_info "Installing for user: $INSTALL_USER"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_warn "Not running as root. Some operations may require sudo."
        if ! command -v sudo &>/dev/null; then
            log_error "sudo not found. Please run as root or install sudo."
            exit 1
        fi
    fi
    
    # For Docker, just run the LazyVim installer if needed
    if [ "$env_type" = "docker" ] && [ -f /usr/local/bin/install_lazyvim.sh ]; then
        if [ "$SKIP_LAZYVIM" = "false" ]; then
            log_info "Running LazyVim installation in Docker container"
            /usr/local/bin/install_lazyvim.sh
        fi
        exit 0
    fi
    
    # Create user if requested
    if [ "$CREATE_USER" = "true" ] && [ "$INSTALL_USER" != "root" ]; then
        if ! id "$INSTALL_USER" &>/dev/null; then
            run_script scripts/setup-user.sh "$INSTALL_USER" "$SETUP_SSH"
        else
            log_info "User $INSTALL_USER already exists"
        fi
    fi
    
    # Install base packages
    log_info "Installing base packages..."
    run_script scripts/install-base.sh
    
    # Install Neovim
    log_info "Installing Neovim..."
    run_script scripts/install-neovim.sh
    
    # Install development tools
    log_info "Installing development tools..."
    run_script scripts/install-tools.sh
    
    # Create workspace directory
    if [ ! -d "$WORKSPACE_DIR" ]; then
        log_info "Creating workspace directory: $WORKSPACE_DIR"
        mkdir -p "$WORKSPACE_DIR"
        if [ "$INSTALL_USER" != "root" ]; then
            chown "$INSTALL_USER:$INSTALL_USER" "$WORKSPACE_DIR"
        fi
    fi
    
    # Setup user directories
    if [ "$INSTALL_USER" != "root" ]; then
        USER_HOME="/home/$INSTALL_USER"
    else
        USER_HOME="/root"
    fi
    
    log_info "Setting up user directories for $INSTALL_USER"
    install -d -o "$INSTALL_USER" -g "$INSTALL_USER" \
        "$USER_HOME/.config/nvim" \
        "$USER_HOME/.local/share/nvim" \
        "$USER_HOME/.local/state" \
        "$USER_HOME/.cache"
    
    # Download and install plugin configurations
    log_info "Installing Neovim plugin configurations..."
    PLUGIN_DIR="$USER_HOME/.config/nvim/lua/plugins"
    mkdir -p "$PLUGIN_DIR"
    
    for plugin in disable.lua lazygit.lua python.lua ts.lua; do
        log_info "Installing plugin: $plugin"
        download_file "plugins/$plugin" "$PLUGIN_DIR/$plugin"
    done
    
    chown -R "$INSTALL_USER:$INSTALL_USER" "$USER_HOME/.config/nvim"
    
    # Install LazyVim
    if [ "$SKIP_LAZYVIM" = "false" ]; then
        log_info "Installing LazyVim..."
        
        # Download and run the LazyVim installer as the target user
        if [ "$INSTALL_USER" = "root" ]; then
            bash <(curl -fsSL "$GITHUB_RAW_URL/docker/install_lazyvim.sh")
        else
            sudo -u "$INSTALL_USER" -H bash <(curl -fsSL "$GITHUB_RAW_URL/docker/install_lazyvim.sh")
        fi
    fi
    
    # Setup SSH if requested
    if [ "$SETUP_SSH" = "true" ]; then
        log_info "Configuring SSH server..."
        run_script scripts/setup-user.sh --ssh-only
    fi
    
    log_info "Installation complete!"
    log_info "User: $INSTALL_USER"
    log_info "Workspace: $WORKSPACE_DIR"
    if [ -n "$CT_NAME" ]; then
        log_info "Container Name: $CT_NAME"
    fi
    
    if [ "$env_type" = "container" ] || [ "$env_type" = "vm" ]; then
        log_info ""
        log_info "To start using Neovim, run: nvim"
        if [ "$INSTALL_USER" != "$USER" ] && [ "$INSTALL_USER" != "root" ]; then
            log_info "Switch to the dev user: su - $INSTALL_USER"
        fi
    fi
}

# Run main installation
main