{
  description = "NixOS development container equivalent to Ubuntu container-setup.sh";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # Development shell for container usage
        devShells.default = pkgs.mkShell {
          name = "lazyvimmer-dev";
          
          buildInputs = with pkgs; [
            # Essential development tools
            curl
            wget
            git
            gnumake
            gcc
            glibc
            
            # Python 3.13 environment (equivalent to Ubuntu 25.04's Python 3.13.3)
            python3
            python3Packages.pip
            python3Packages.setuptools
            python3Packages.wheel
            python3Packages.virtualenv
            
            # Node.js 20.x (equivalent to Ubuntu 25.04's Node.js 20.18.1)
            nodejs_20
            npm-check-updates
            
            # uv - Python package manager
            uv
            
            # GitHub CLI with authentication support
            gh
            
            # atuin - shell history tool
            atuin
            
            # Development utilities
            vim
            nano
            htop
            nettools
            iputils
            dnsutils
            
            # Optional Docker support
            docker
            docker-compose
            
            # Build tools
            pkg-config
            openssl
            zlib
            
            # System utilities
            sudo
            gnupg
            openssh
          ];
          
          shellHook = ''
            # Set locale (equivalent to Ubuntu setup)
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
            
            # Configure GitHub CLI if GITHUB_TOKEN is set
            if [ -n "$GITHUB_TOKEN" ]; then
              echo "Configuring GitHub CLI authentication..."
              echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null || echo "GitHub CLI auth failed"
            fi
            
            # Setup atuin if not configured
            if [ ! -f "$HOME/.config/atuin/config.toml" ] && command -v atuin &> /dev/null; then
              echo "Initializing atuin..."
              atuin init bash --disable-up-arrow > /dev/null 2>&1 || true
            fi
            
            echo "🚀 Development environment ready!"
            echo "Python: $(python --version 2>/dev/null || python3 --version)"
            echo "Node.js: $(node --version)"
            echo "npm: $(npm --version)"
            echo "uv: $(uv --version)"
            echo "GitHub CLI: $(gh --version | head -1)"
            echo "atuin: $(atuin --version)"
            
            # Show authentication status
            if [ -n "$GITHUB_TOKEN" ] && gh auth status &>/dev/null; then
              echo "GitHub CLI: Authenticated"
            fi
          '';
          
          # Environment variables
          NIX_SHELL_PRESERVE_PROMPT = 1;
        };
        
        # NixOS module for container/system installation
        nixosModules.default = { config, lib, pkgs, ... }: {
          # System packages equivalent to container-setup.sh
          environment.systemPackages = with pkgs; [
            # Essential packages
            curl
            wget
            git
            gnumake
            gcc
            glibc
            sudo
            gnupg
            openssh
            unzip
            gzip
            tar
            
            # Python 3.13 with development packages
            python3
            python3Packages.pip
            python3Packages.setuptools
            python3Packages.wheel
            python3Packages.virtualenv
            
            # Node.js 20.x and npm
            nodejs_20
            
            # Python package manager
            uv
            
            # GitHub CLI
            gh
            
            # Shell history tool
            atuin
            
            # Development tools
            vim
            nano
            htop
            nettools
            iputils
            dnsutils
            
            # Optional Docker (when enabled)
          ] ++ lib.optionals config.virtualisation.docker.enable [
            docker
            docker-compose
          ];
          
          # Enable SSH daemon
          services.openssh = {
            enable = true;
            settings = {
              PermitRootLogin = "no";
              PasswordAuthentication = false;
              PubkeyAuthentication = true;
            };
          };
          
          # Create dev user with sudo access
          users.users.dev = {
            isNormalUser = true;
            home = "/home/dev";
            description = "Development user";
            extraGroups = [ "wheel" "networkmanager" ] 
              ++ lib.optionals config.virtualisation.docker.enable [ "docker" ];
            shell = pkgs.bash;
            openssh.authorizedKeys.keys = [
              # SSH keys will be added here or fetched from GitHub
            ];
          };
          
          # Sudo configuration for dev user
          security.sudo.extraRules = [
            {
              users = [ "dev" ];
              commands = [
                {
                  command = "ALL";
                  options = [ "NOPASSWD" ];
                }
              ];
            }
          ];
          
          # Locale configuration
          i18n.defaultLocale = "en_US.UTF-8";
          i18n.extraLocaleSettings = {
            LC_ADDRESS = "en_US.UTF-8";
            LC_IDENTIFICATION = "en_US.UTF-8";
            LC_MEASUREMENT = "en_US.UTF-8";
            LC_MONETARY = "en_US.UTF-8";
            LC_NAME = "en_US.UTF-8";
            LC_NUMERIC = "en_US.UTF-8";
            LC_PAPER = "en_US.UTF-8";
            LC_TELEPHONE = "en_US.UTF-8";
            LC_TIME = "en_US.UTF-8";
          };
          
          # Optional Docker support
          virtualisation.docker = {
            enable = false; # Can be overridden
            enableOnBoot = true;
          };
          
          # Enable container features
          boot.enableContainers = true;
          
          # Network configuration (DHCP like Ubuntu setup)
          networking.useDHCP = true;
          networking.firewall.enable = true;
          networking.firewall.allowedTCPPorts = [ 22 ]; # SSH
          
          # System state version
          system.stateVersion = "24.05";
          
          # Environment variables for all users
          environment.variables = {
            LANG = "en_US.UTF-8";
            LC_ALL = "en_US.UTF-8";
          };
          
          # Shell initialization for dev user
          programs.bash.shellInit = ''
            # Add user bin to PATH
            export PATH="$HOME/.local/bin:$PATH"
            
            # Initialize atuin if available
            if command -v atuin &> /dev/null; then
              eval "$(atuin init bash)"
            fi
          '';
        };
      }
    ) // {
      # NixOS configuration for direct system installation
      nixosConfigurations.devcontainer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.default
          {
            # Enable Docker by default for containers
            virtualisation.docker.enable = true;
            
            # Container-specific configurations
            boot.isContainer = true;
            networking.hostName = "devcontainer";
            
            # Minimal boot configuration for containers
            boot.loader.grub.enable = false;
            boot.initrd.enable = false;
            boot.kernel.sysctl."kernel.unprivileged_userns_clone" = 1;
          }
        ];
      };
    };
}