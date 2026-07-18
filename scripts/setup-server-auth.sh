#!/usr/bin/env bash
# One-time: push our SSH public key to the PDP server so future connections are passwordless.
# Safe to re-run — ssh-copy-id is idempotent.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

PUBKEY="${PDP_SSH_KEY}.pub"
if [[ ! -f "$PUBKEY" ]]; then
    echo "error: public key not found at $PUBKEY" >&2
    exit 1
fi

echo ">>> installing $PUBKEY on $PDP_SERVER_USER@$PDP_SERVER_HOST..."

if command -v sshpass >/dev/null 2>&1; then
    SSHPASS="$PDP_SERVER_PASS" sshpass -e ssh-copy-id \
        -i "$PUBKEY" \
        -o StrictHostKeyChecking=accept-new \
        "$PDP_SERVER_USER@$PDP_SERVER_HOST"
else
    echo "sshpass not found — ssh-copy-id will prompt for the password interactively."
    ssh-copy-id -i "$PUBKEY" \
        -o StrictHostKeyChecking=accept-new \
        "$PDP_SERVER_USER@$PDP_SERVER_HOST"
fi

# sshd refuses pubkey auth when $HOME is group-writable (StrictModes).
# The shared group account on this server ships with drwxrws--- — trim group write.
echo ">>> normalising server-side perms for sshd StrictModes..."
if command -v sshpass >/dev/null 2>&1; then
    sshpass -p "$PDP_SERVER_PASS" ssh \
        -o StrictHostKeyChecking=accept-new \
        "$PDP_SERVER_USER@$PDP_SERVER_HOST" \
        'chmod g-w ~ && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && ls -lad ~ ~/.ssh ~/.ssh/authorized_keys'
else
    echo "   (sshpass missing — if verify below fails, run this on the server:"
    echo "     chmod g-w ~ && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys)"
fi

echo ">>> verifying passwordless login..."
if ssh -o BatchMode=yes -o ConnectTimeout=8 \
       -i "$PDP_SSH_KEY" \
       "$PDP_SERVER_USER@$PDP_SERVER_HOST" 'echo ok'; then
    echo ">>> success — you can now use scripts/connect-server.sh without a password."
else
    echo "error: passwordless ssh still failing. Check the key / server config." >&2
    exit 1
fi
