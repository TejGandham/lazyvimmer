# Debian Trixie Development Container with Nix
# Python 3.13 + Node.js 22.20.0 + Development Tools
# Built with Nix package manager for reproducibility

FROM debian:trixie

LABEL maintainer="Lazyvimmer Project"
LABEL description="Debian Trixie development environment with Nix, Python 3.13, and Node.js 22.20.0"

# Set environment variables
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# Install minimal Debian packages required for Nix
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        xz-utils \
        git \
        locales \
    && \
    # Configure locale
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && \
    # Clean up
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Nix package manager using Determinate Systems installer
# This installer is designed for containers and includes integrity checks
# --init none: No init system (required for Docker without systemd)
# --no-start-daemon: Don't try to start daemon
# --extra-conf "sandbox = false": Required for Docker/Podman compatibility
RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux \
    --init none \
    --extra-conf "sandbox = false" \
    --no-start-daemon \
    --no-confirm

# Set up Nix environment
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

# Source Nix profile for this build
SHELL ["/bin/bash", "-c"]
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && \
    nix --version

# Copy flake configuration to /app to avoid conflict with workspace mount
COPY flake.nix /app/flake.nix

# Enable Nix flakes and build the development environment
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && \
    cd /app && \
    nix develop --command echo "Nix development environment built successfully"

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Auto-activate Nix environment in all interactive shells (for VS Code, SSH, etc.)
RUN echo 'source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' >> /root/.bashrc && \
    echo 'if [ -d /app ]; then' >> /root/.bashrc && \
    echo '  eval "$(nix print-dev-env /app 2>/dev/null || true)"' >> /root/.bashrc && \
    echo 'fi' >> /root/.bashrc

# Set working directory
WORKDIR /workspace

# Use entrypoint to activate Nix environment
ENTRYPOINT ["/entrypoint.sh"]

# Default to interactive bash shell
CMD ["/bin/bash"]
