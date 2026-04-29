#!/usr/bin/env bash
# Launch an X2GO session to the PDP server (full MATE desktop over NX).
# Recommended for long Vivado sessions — much smoother than X11 forwarding.
#
# First run only: installs a session entry at ~/.x2goclient/sessions so
# you see "PDP Server (Group 24)" in the x2goclient GUI.
#
# Requires x2goclient to be installed on this laptop. If not:
#   sudo apt install x2goclient

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

if ! command -v x2goclient >/dev/null 2>&1; then
    echo "error: x2goclient is not installed." >&2
    echo "       install it with: sudo apt install x2goclient" >&2
    exit 1
fi

SESSION_FILE="$HOME/.x2goclient/sessions"
SESSION_NAME="PDP Server (Group $PDP_GROUP_NUMBER)"
mkdir -p "$(dirname "$SESSION_FILE")"

# Seed a default session if we've never configured one. x2goclient rewrites
# this file on every change, so don't fight it — only create if missing.
if [[ ! -f "$SESSION_FILE" ]] || ! grep -q "^name=$SESSION_NAME" "$SESSION_FILE" 2>/dev/null; then
    echo ">>> seeding x2goclient session '$SESSION_NAME'..."
    # 16 hex chars; arbitrary but stable.
    SESSION_ID="pdpg$(echo -n "$PDP_SERVER_HOST$PDP_SERVER_USER" | md5sum | cut -c1-12)"
    cat >> "$SESSION_FILE" <<EOF

[$SESSION_ID]
name=$SESSION_NAME
host=$PDP_SERVER_HOST
user=$PDP_SERVER_USER
sshport=22
key=$PDP_SSH_KEY
usesshproxy=false
command=MATE
rootless=false
sessiontype=D
sound=false
setsessiontitle=true
sessiontitle=$SESSION_NAME
quality=9
pack=16m-jpeg
fullscreen=false
width=1920
height=1200
setdpi=true
dpi=96
clipboard=both
EOF
fi

echo ">>> launching x2goclient..."
echo "    double-click the '$SESSION_NAME' card, or press Enter when selected."
exec x2goclient --session-conf="$SESSION_FILE"
