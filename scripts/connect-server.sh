#!/usr/bin/env bash
# SSH into the PDP server. Forwards any extra args to ssh (so you can run
# a one-shot command: `./scripts/connect-server.sh 'ls ~/pdp-project'`).
#
# Uses pubkey auth if installed (see setup-server-auth.sh). Falls back to
# sshpass with the stored password if pubkey auth hasn't been set up yet.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

SSH_ARGS=(
    -i "$PDP_SSH_KEY"
    -A                              # forward our ssh-agent so the server can git-clone/push using our key
    -o ServerAliveInterval=60
    -o ServerAliveCountMax=3
)

# Try pubkey auth first (silent probe). If it works, use it.
if ssh -o BatchMode=yes -o ConnectTimeout=8 "${SSH_ARGS[@]}" \
       "$PDP_SERVER_USER@$PDP_SERVER_HOST" 'true' 2>/dev/null; then
    exec ssh "${SSH_ARGS[@]}" "$PDP_SERVER_USER@$PDP_SERVER_HOST" "$@"
fi

# Pubkey not yet installed — fall back to password auth via sshpass.
if ! command -v sshpass >/dev/null 2>&1; then
    echo "error: pubkey auth not set up and sshpass is not installed." >&2
    echo "       run ./scripts/setup-server-auth.sh once, or install sshpass." >&2
    exit 1
fi

echo "note: using password auth — run ./scripts/setup-server-auth.sh once to skip this." >&2
exec sshpass -p "$PDP_SERVER_PASS" ssh "${SSH_ARGS[@]}" \
     "$PDP_SERVER_USER@$PDP_SERVER_HOST" "$@"
