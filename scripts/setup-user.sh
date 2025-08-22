#!/usr/bin/env bash
set -euo pipefail

# Setup user and optional SSH configuration

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

# Default values
SSH_ONLY=false

# Parse arguments
if [ "$1" = "--ssh-only" ]; then
    SSH_ONLY=true
else
    NEW_USER="${1:-dev}"
    SETUP_SSH="${2:-false}"
fi

# Function to configure SSH
configure_ssh() {
    log_info "Configuring SSH server..."
    
    # Install SSH server if not present
    if ! command -v sshd &>/dev/null; then
        log_info "Installing OpenSSH server..."
        if [ "$EUID" -eq 0 ]; then
            apt-get update -y
            apt-get install -y openssh-server
        else
            sudo apt-get update -y
            sudo apt-get install -y openssh-server
        fi
    fi
    
    # Configure SSH settings
    log_info "Updating SSH configuration..."
    local SSH_CONFIG="/etc/ssh/sshd_config"
    
    if [ "$EUID" -eq 0 ]; then
        # Enable password authentication (optional)
        sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' "$SSH_CONFIG"
        # Disable root login
        sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' "$SSH_CONFIG"
        # Enable public key authentication
        sed -ri 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' "$SSH_CONFIG"
        
        # Restart SSH service
        if systemctl is-active --quiet ssh; then
            systemctl restart ssh
        else
            systemctl enable --now ssh
        fi
    else
        sudo sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' "$SSH_CONFIG"
        sudo sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' "$SSH_CONFIG"
        sudo sed -ri 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' "$SSH_CONFIG"
        
        if systemctl is-active --quiet ssh; then
            sudo systemctl restart ssh
        else
            sudo systemctl enable --now ssh
        fi
    fi
    
    log_info "SSH server configured and running"
}

# Function to create user
create_user() {
    local username="$1"
    local setup_ssh="$2"
    
    log_info "Creating user: $username"
    
    if [ "$EUID" -ne 0 ]; then
        log_error "User creation requires root privileges"
        exit 1
    fi
    
    # Create user with home directory and bash shell
    useradd -m -s /bin/bash "$username"
    
    # Set default password (should be changed)
    echo "${username}:${username}" | chpasswd
    log_info "Default password set to: $username (PLEASE CHANGE THIS)"
    
    # Add to sudo group
    usermod -aG sudo "$username"
    
    # Configure passwordless sudo (optional, for development)
    echo "${username} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${username}"
    chmod 440 "/etc/sudoers.d/90-${username}"
    
    # Create SSH directory
    mkdir -p "/home/${username}/.ssh"
    chown -R "${username}:${username}" "/home/${username}/.ssh"
    chmod 700 "/home/${username}/.ssh"
    
    # Create XDG directories
    install -d -o "$username" -g "$username" \
        "/home/${username}/.config" \
        "/home/${username}/.local/share" \
        "/home/${username}/.local/state" \
        "/home/${username}/.cache"
    
    log_info "User $username created successfully"
    
    # Setup SSH if requested
    if [ "$setup_ssh" = "true" ]; then
        configure_ssh
    fi
}

# Main logic
if [ "$SSH_ONLY" = "true" ]; then
    configure_ssh
else
    if id "$NEW_USER" &>/dev/null; then
        log_info "User $NEW_USER already exists"
    else
        if [ "$EUID" -ne 0 ]; then
            log_error "This script must be run as root to create users"
            log_info "Try: sudo $0 $*"
            exit 1
        fi
        create_user "$NEW_USER" "$SETUP_SSH"
    fi
fi