#!/usr/bin/env bash
# Unmount the SSHFS mount of the PDP server's $HOME.

set -euo pipefail

MOUNT_DIR="${PDP_MOUNT_DIR:-$HOME/pdp-server-mnt}"

if ! mountpoint -q "$MOUNT_DIR"; then
    echo "nothing mounted at $MOUNT_DIR"
    exit 0
fi

if command -v fusermount3 >/dev/null 2>&1; then
    fusermount3 -u "$MOUNT_DIR"
elif command -v fusermount >/dev/null 2>&1; then
    fusermount -u "$MOUNT_DIR"
else
    umount "$MOUNT_DIR"
fi

echo ">>> unmounted $MOUNT_DIR"
