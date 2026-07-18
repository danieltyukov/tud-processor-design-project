#!/usr/bin/env bash
# ============================================================================
#  launch-server-session.sh - open a server desktop session over plain SSH+X11
# ----------------------------------------------------------------------------
#  Built as the X2Go replacement after X2Go got blocked by stale /tmp/.X*-lock
#  files left by other course groups on the shared cese4040-24 account. This
#  bypasses X2Go entirely: it opens an SSH session with X11 forwarding (-Y)
#  and launches MATE components as individual forwarded windows on your laptop.
#
#  Two modes:
#
#    ./scripts/launch-server-session.sh                # just a server terminal
#         -> single mate-terminal window (server shell, ready to run vivado,
#            git, vim, anything). Lightest, most reliable.
#
#    ./scripts/launch-server-session.sh --desktop      # terminal + panel + WM
#         -> mate-terminal + mate-panel (taskbar) + marco (window manager) +
#            caja (file manager).  Feels closer to a real desktop. Windows are
#            still individual X11-forwarded apps to your local screen.
#
#  Requires:
#    - your laptop X server is running (DISPLAY is set; xset q works)
#    - VPN up (the SSH connection itself)
#    - x2goclient NOT needed
#
#  Notes:
#    - When the main terminal exits, the SSH session ends and any background
#      apps (panel/WM/caja) get cleaned up by SIGHUP.
#    - Closing the terminal window does NOT log you out of any other ssh
#      sessions you have open separately.
#    - GUI perf is "fine for menus, slow for heavy block-diagram dragging" -
#      same caveat as ssh-Y Vivado.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

MODE="${1:-terminal}"

if [[ -z "${DISPLAY:-}" ]]; then
    echo "error: \$DISPLAY is empty. Run this from a graphical session." >&2
    exit 1
fi
if ! command -v xset >/dev/null 2>&1 || ! xset q >/dev/null 2>&1; then
    echo "warn: local X server probe failed - the forwarded windows may not appear." >&2
fi

# Remote command: set PATH for Vivado, set a sane title, launch mate-terminal
# (and optionally panel + WM + file manager). The remote shell stays alive as
# long as mate-terminal is open; when terminal exits, panel/WM die via SIGHUP.
case "$MODE" in
    terminal|"")
        REMOTE_CMD='
            export PATH=/opt/apps/xilinx/Vivado/2024.2/bin:$PATH
            cd ~
            mate-terminal --title="cese4040-24 @ ce-procdesign01" --geometry=140x40
        '
        ;;

    --desktop)
        REMOTE_CMD='
            export PATH=/opt/apps/xilinx/Vivado/2024.2/bin:$PATH
            cd ~
            # window manager first so subsequent windows have decorations
            (marco --replace 2>/dev/null &)
            sleep 0.4
            # mate panel (taskbar / clock / menu)
            (mate-panel 2>/dev/null &)
            # file manager (no desktop background to avoid stomping local one)
            (caja --no-desktop ~ 2>/dev/null &)
            sleep 0.3
            # main terminal - exiting this closes the SSH session and cleans up
            mate-terminal --title="cese4040-24 @ ce-procdesign01 (desktop)" --geometry=140x40
        '
        ;;

    -h|--help|help)
        sed -n '2,30p' "$0"   # print the header doc
        exit 0
        ;;

    *)
        echo "error: unknown mode '$MODE'" >&2
        echo "usage: $(basename "$0") [--desktop]" >&2
        exit 2
        ;;
esac

echo ">>> opening server session on $PDP_SERVER_HOST via SSH+X11 (mode=$MODE)"
echo "    close the terminal window to end the session."

# -Y = trusted X11 forwarding (faster than -X for MATE apps).
# ServerAlive keeps the SSH channel alive over slow VPN links.
exec ssh -Y -i "$PDP_SSH_KEY" \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    "$PDP_SERVER_USER@$PDP_SERVER_HOST" \
    "bash -lc '$REMOTE_CMD'"
