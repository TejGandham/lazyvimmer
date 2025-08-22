#!/usr/bin/env bash
set -euo pipefail
install -d -o dev -g dev /home/dev/.config /home/dev/.local/share /home/dev/.local/state /home/dev/.cache || true
chown -R dev:dev /home/dev/.config /home/dev/.local || true

if [ -d /home/dev/.ssh ]; then chmod 700 /home/dev/.ssh || true; fi
if [ -f /home/dev/.ssh/authorized_keys ]; then chmod 600 /home/dev/.ssh/authorized_keys || true; fi

if [ "${RUN_LAZYVIM_SETUP:-0}" = "1" ]; then
  if [ -x /usr/local/bin/install_lazyvim.sh ]; then
    INSTALL_USER=dev /usr/local/bin/install_lazyvim.sh
  else
    echo "WARN: installer missing" >&2
  fi
fi

exec /usr/sbin/sshd -D -e
