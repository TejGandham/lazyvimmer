#!/bin/bash
# Entrypoint script for Debian Trixie Nix development container
# Activates Nix environment and provides GitHub integration

set -e

# Source Nix profile to make Nix commands available
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Change to workspace directory
cd /workspace

# Optional: Fetch GitHub SSH keys at runtime
if [ -n "$GITHUB_USER" ]; then
    # Validate GITHUB_USER to prevent command injection
    if ! [[ "$GITHUB_USER" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "🚨 Invalid GITHUB_USER format. Must contain only alphanumeric characters and hyphens."
        exit 1
    fi

    echo "📥 Fetching SSH keys from GitHub for user: $GITHUB_USER"
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh

    # Fetch keys from GitHub and validate response
    if curl -fsSL "https://github.com/$GITHUB_USER.keys" -o /tmp/gh_keys 2>/dev/null; then
        # Validate that response contains valid SSH keys
        if [ -s /tmp/gh_keys ] && grep -q "^ssh-" /tmp/gh_keys; then
            cat /tmp/gh_keys >> /root/.ssh/authorized_keys
            chmod 600 /root/.ssh/authorized_keys
            echo "✓ SSH keys fetched successfully"
        else
            echo "⚠ Invalid SSH key format from GitHub or no keys found"
        fi
        rm -f /tmp/gh_keys
    else
        echo "⚠ Failed to fetch SSH keys from GitHub"
    fi
fi

# Note: GitHub CLI automatically uses GITHUB_TOKEN environment variable
# No explicit authentication command needed

# Display environment information
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐧 Debian Trixie + Nix Development Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Execute the provided command in the Nix development environment
# Use the flake from /app directory (not affected by workspace mount)
if [ $# -eq 0 ]; then
    # Interactive mode
    exec nix develop /app --command /bin/bash
else
    # Execute provided command
    exec nix develop /app --command "$@"
fi
