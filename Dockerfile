FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Base
RUN apt-get update -y && apt-get install -y --no-install-recommends   openssh-server sudo git curl wget ca-certificates gnupg lsb-release   build-essential make unzip tar rsync ripgrep fd-find   python3 python3-venv python3-pip software-properties-common xz-utils   && rm -rf /var/lib/apt/lists/*

# fd alias (Ubuntu names it fdfind)
RUN if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then ln -s /usr/bin/fdfind /usr/local/bin/fd; fi

# Neovim pinned with filename fallback
ARG NEOVIM_VERSION=0.10.2
RUN set -eux;   ARCH="$(dpkg --print-architecture)";   case "$ARCH" in amd64) FN1="nvim-linux64.tar.gz"; FN2="nvim-linux-x86_64.tar.gz" ;; arm64) FN1="nvim-linux-arm64.tar.gz"; FN2="$FN1" ;; *) exit 1 ;; esac;   for FN in "$FN1" "$FN2"; do URL="https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/${FN}"; if curl -fsSL -o /tmp/nvim.tar.gz "$URL"; then break; fi; done;   tar -xzf /tmp/nvim.tar.gz -C /opt; DIR="$(tar -tzf /tmp/nvim.tar.gz | head -1 | cut -d/ -f1)";   ln -sf "/opt/${DIR}/bin/nvim" /usr/local/bin/nvim; rm /tmp/nvim.tar.gz; nvim --version | head -n1

# Lazygit pinned
ARG LAZYGIT_VERSION=0.44.1
RUN set -eux;   ARCH="$(dpkg --print-architecture)";   case "$ARCH" in amd64) REL_ARCH="Linux_x86_64" ;; arm64) REL_ARCH="Linux_arm64" ;; *) exit 1 ;; esac;   curl -fsSL -o /tmp/lazygit.tgz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_${REL_ARCH}.tar.gz";   tar -xzf /tmp/lazygit.tgz -C /usr/local/bin lazygit; rm -f /tmp/lazygit.tgz; lazygit --version

# Node LTS + Claude Code
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -   && apt-get update -y && apt-get install -y nodejs   && npm i -g @anthropic-ai/claude-code   && rm -rf /var/lib/apt/lists/*

# uv - Fast Python package manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# dev user + ssh
ARG DEVUSER=dev
ARG DEVPASS=dev
RUN useradd -m -s /bin/bash ${DEVUSER}   && echo "${DEVUSER}:${DEVPASS}" | chpasswd   && usermod -aG sudo ${DEVUSER}   && echo "${DEVUSER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${DEVUSER}   && mkdir -p /var/run/sshd /home/${DEVUSER}/.ssh   && chown -R ${DEVUSER}:${DEVUSER} /home/${DEVUSER}/.ssh   && chmod 700 /home/${DEVUSER}/.ssh   && sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config   && sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config   && sed -ri 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# XDG dirs
RUN install -d -o dev -g dev /home/dev/.config/nvim /home/dev/.local/share/nvim /home/dev/.local/state /home/dev/.cache

# Workspace
RUN mkdir -p /workspace && chown ${DEVUSER}:${DEVUSER} /workspace

# Copy scripts and plugin files
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/install_lazyvim.sh /usr/local/bin/install_lazyvim.sh
COPY plugins/ /home/dev/.config/nvim/lua/plugins/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/install_lazyvim.sh   && chown -R dev:dev /home/dev/.config/nvim

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
