# NixOS Configuration for Development Container
# Equivalent to Ubuntu container-setup.sh functionality
# 
# Usage:
#   1. Copy this file to /etc/nixos/configuration.nix (or import it)
#   2. Run: sudo nixos-rebuild switch
#   3. Optionally set GITHUB_TOKEN environment variable for GitHub CLI auth
#   4. Optionally set GITHUB_USERNAME to fetch SSH keys

{ config, lib, pkgs, ... }:

let
  # GitHub username for SSH key fetching (set via environment or override)
  githubUsername = builtins.getEnv "GITHUB_USERNAME";
  
  # Fetch SSH keys from GitHub if username is provided
  fetchGitHubKeys = username:
    if username != "" then
      let
        keysUrl = "https://github.com/${username}.keys";
        keysContent = builtins.fetchurl keysUrl;
      in
        lib.splitString "\n" (lib.removeSuffix "\n" keysContent)
    else [];

in {
  imports = [
    # Include hardware configuration if it exists
    # ./hardware-configuration.nix
  ];

  # System packages equivalent to container-setup.sh
  environment.systemPackages = with pkgs; [
    # Essential packages (equivalent to apt install essentials)
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
    pkg-config
    openssl
    zlib
    
    # Python 3.13 with development packages (equivalent to python3, python3-pip, python3-venv, python3-dev)
    python3
    python3Packages.pip
    python3Packages.setuptools
    python3Packages.wheel
    python3Packages.virtualenv
    
    # Node.js 20.x and npm (equivalent to Ubuntu 25.04 nodejs npm packages)
    nodejs_20
    
    # uv - Python package manager (equivalent to curl install)
    uv
    
    # GitHub CLI (equivalent to gh CLI via apt)
    gh
    
    # atuin - shell history tool (equivalent to curl install)
    atuin
    
    # Development tools (equivalent to vim, nano, htop, net-tools, etc.)
    vim
    nano
    htop
    nettools
    iputils
    dnsutils
    
    # Docker support (equivalent to docker-ce, docker-compose-plugin)
    docker
    docker-compose
    
    # Additional build dependencies
    autoconf
    automake
    libtool
    cmake
  ];

  # Enable SSH daemon (equivalent to SSH setup in container-setup.sh)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";  # Disable root SSH login for security
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
    };
  };

  # Create dev user with sudo access (equivalent to user creation in script)
  users.users.dev = {
    isNormalUser = true;
    home = "/home/dev";
    description = "Development user";
    extraGroups = [ 
      "wheel"          # sudo access
      "networkmanager" # network management
      "docker"         # docker access
    ];
    shell = pkgs.bash;
    
    # SSH keys from GitHub (equivalent to curl GitHub keys in script)
    openssh.authorizedKeys.keys = fetchGitHubKeys githubUsername;
    
    # Additional manual SSH keys can be added here
    # openssh.authorizedKeys.keys = [
    #   "ssh-rsa AAAA... your-key-here"
    # ];
  };

  # Sudo configuration for dev user (equivalent to NOPASSWD sudo setup)
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

  # Locale configuration (equivalent to locale-gen and update-locale)
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

  # Docker configuration (equivalent to Docker CE installation)
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    
    # Equivalent to adding user to docker group
    # (handled via users.users.dev.extraGroups above)
  };

  # Enable container features for LXC compatibility
  boot.enableContainers = true;
  
  # Container-specific boot configuration
  boot.isContainer = lib.mkDefault false;  # Set to true for LXC containers
  
  # Network configuration (equivalent to DHCP setup)
  networking = {
    useDHCP = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ]; # SSH port
    };
  };

  # Environment variables (equivalent to .bashrc exports)
  environment.variables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    
    # Add user bin to PATH globally
    # Note: Individual user PATH setup in programs.bash.shellInit
  };

  # Bash shell configuration for all users
  programs.bash = {
    enable = true;
    
    # Shell initialization (equivalent to .bashrc modifications)
    shellInit = ''
      # Add user local bin to PATH (equivalent to PATH export in .bashrc)
      export PATH="$HOME/.local/bin:$PATH"
      
      # Initialize atuin if available (equivalent to atuin init bash in .bashrc)
      if command -v atuin &> /dev/null; then
        eval "$(atuin init bash)"
      fi
    '';
    
    # Shell aliases (equivalent to custom .bashrc entries)
    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
      
      # Git aliases
      gs = "git status";
      gd = "git diff";
      
      # Docker aliases
      dc = "docker compose";
    };
  };

  # System-wide activation script for additional setup
  system.activationScripts.devSetup = {
    text = ''
      # Create necessary directories
      mkdir -p /home/dev/.local/bin
      chown dev:users /home/dev/.local/bin 2>/dev/null || true
      
      # Install Claude Code CLI if npm is available and not already installed
      if command -v npm &> /dev/null && ! command -v claude &> /dev/null; then
        echo "Installing Claude Code CLI..."
        npm install -g @anthropic-ai/claude-code 2>/dev/null || true
      fi
    '';
    deps = [ ];
  };

  # Enable nix flakes and command (for development)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Allow unfree packages if needed
  nixpkgs.config.allowUnfree = true;

  # System state version (adjust as needed)
  system.stateVersion = "24.05";

  # Additional systemd services can be added here
  # For example, to automatically configure GitHub CLI:
  systemd.services.github-cli-setup = {
    description = "Setup GitHub CLI authentication";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      User = "dev";
      Group = "users";
      WorkingDirectory = "/home/dev";
    };
    
    script = ''
      # Configure GitHub CLI if GITHUB_TOKEN environment variable is set
      if [ -n "$GITHUB_TOKEN" ] && command -v gh &> /dev/null; then
        echo "Configuring GitHub CLI authentication..."
        echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null || echo "GitHub CLI auth failed"
      fi
    '';
    
    environment = {
      HOME = "/home/dev";
      # GITHUB_TOKEN can be set via environment
    };
  };

  # Optional: Enable automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Optional: Enable auto-upgrade
  system.autoUpgrade = {
    enable = false;  # Set to true for automatic updates
    dates = "weekly";
  };
}