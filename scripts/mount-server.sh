#!/usr/bin/env bash
# Mount the server's home directory at ~/pdp-server-mnt via SSHFS so we can
# browse / edit server files as if they were local. Requires pubkey auth
# (run setup-server-auth.sh once first).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

MOUNT_DIR="${PDP_MOUNT_DIR:-$HOME/pdp-server-mnt}"

if ! command -v sshfs >/dev/null 2>&1; then
    echo "error: sshfs not installed. install it with:" >&2
    echo "   sudo apt install sshfs" >&2
    exit 1
fi

mkdir -p "$MOUNT_DIR"

if mountpoint -q "$MOUNT_DIR"; then
    echo "already mounted at $MOUNT_DIR"
    exit 0
fi

echo ">>> mounting $PDP_SERVER_USER@$PDP_SERVER_HOST:\$HOME on $MOUNT_DIR..."

# Empty remote path → sshfs mounts the remote user's $HOME wherever sshd
# places it (on this server it's /data/home/..., not /home/...).
sshfs "$PDP_SERVER_USER@$PDP_SERVER_HOST:" "$MOUNT_DIR" \
    -o IdentityFile="$PDP_SSH_KEY" \
    -o reconnect \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=3 \
    -o follow_symlinks \
    -o idmap=user

echo ">>> mounted. ls:"
ls "$MOUNT_DIR" | head
echo ""
echo "unmount with: ./scripts/umount-server.sh"
