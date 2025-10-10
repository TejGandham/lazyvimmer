{
  description = "Debian Trixie development environment with Python 3.13 and Node.js 22.20.0";

  inputs = {
    # Use nixpkgs-unstable for latest packages including Python 3.13
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Python 3.13 - latest stable with full package support
        python = pkgs.python313;

        # Node.js 22 - exact major version required (will fail if not available)
        nodejs = pkgs.nodejs_22;

      in
      {
        # Development shell for Debian container usage
        devShells.default = pkgs.mkShell {
          name = "debian-trixie-dev";

          buildInputs = with pkgs; [
            # Essential development tools
            curl
            wget
            git
            gnumake
            gcc
            glibc

            # Python 3.13 with development packages
            python
            python.pkgs.pip
            python.pkgs.setuptools
            python.pkgs.wheel
            python.pkgs.virtualenv

            # Node.js 22.x with npm
            nodejs

            # uv - Ultra-fast Python package manager
            uv

            # GitHub CLI
            gh

            # atuin - Shell history tool
            atuin

            # Development utilities
            vim
            nano
            htop
            nettools
            iputils
            dnsutils

            # Build tools
            pkg-config
            openssl
            zlib

            # System utilities
            gnupg
            openssh
          ];

          shellHook = ''
            # Set locale
            export LANG=en_US.UTF-8
            export LC_ALL=en_US.UTF-8

            # Ensure user bin directory exists and is in PATH
            mkdir -p $HOME/.local/bin
            export PATH="$HOME/.local/bin:$PATH"

            # Install Claude Code CLI if not present
            if ! command -v claude &> /dev/null; then
              echo "Installing Claude Code CLI..."
              npm install -g @anthropic-ai/claude-code
            fi

            # Note: GitHub CLI automatically uses GITHUB_TOKEN environment variable
            # No explicit authentication needed if GITHUB_TOKEN is set

            # Setup atuin if not configured
            if [ ! -f "$HOME/.config/atuin/config.toml" ] && command -v atuin &> /dev/null; then
              echo "Initializing atuin..."
              atuin init bash --disable-up-arrow > /dev/null 2>&1 || true
            fi

            echo ""
            echo "🚀 Debian Trixie Development Environment Ready!"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Python:     $(python --version 2>/dev/null || python3 --version)"
            echo "Node.js:    $(node --version)"
            echo "npm:        $(npm --version)"
            echo "uv:         $(uv --version 2>/dev/null || echo 'not found')"
            echo "GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'not found')"
            echo "atuin:      $(atuin --version 2>/dev/null || echo 'not found')"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""

            # Show GitHub CLI authentication status
            if [ -n "$GITHUB_TOKEN" ]; then
              if gh auth status &>/dev/null; then
                echo "✓ GitHub CLI: Authenticated via GITHUB_TOKEN"
              else
                echo "⚠ GITHUB_TOKEN set but authentication failed"
              fi
            fi

            # Python package management info
            echo "💡 Use 'uv pip install <package>' for fast Python package installation"
            echo "💡 Use 'uv pip sync requirements.txt' to install from requirements"
            echo ""
          '';

          # Environment variables
          NIX_SHELL_PRESERVE_PROMPT = 1;
        };
      }
    );
}
