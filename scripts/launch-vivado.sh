#!/usr/bin/env bash
# Open Vivado on the server with X11 forwarded back to this laptop.
# Single-app experience (no full desktop). Fast to start; GUI perf is
# "fine for clicking through menus, painful for block-diagram dragging".
# For a smoother long session, use launch-x2go.sh instead.
#
# Usage:
#   ./scripts/launch-vivado.sh                     # plain vivado GUI, cwd = ~/pdp-project/hardware
#   ./scripts/launch-vivado.sh --create-project    # opens GUI and sources create_project.tcl
#   ./scripts/launch-vivado.sh --sim               # opens GUI, creates project, runs simulation
#   ./scripts/launch-vivado.sh --batch-sim         # headless: run simulation, print results, exit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

MODE="${1:-gui}"

REMOTE_HW="~/pdp-project/hardware"

case "$MODE" in
    --batch-sim)
        echo ">>> running baseline simulation in batch mode on server (no GUI)..."
        ssh -i "$PDP_SSH_KEY" "$PDP_SERVER_USER@$PDP_SERVER_HOST" "bash -lc '
            cd $REMOTE_HW
            vivado -mode batch \
                   -source ./scripts/create_project.tcl \
                   -source ./scripts/run_simulation.tcl \
                   -nojournal -nolog -notrace
        '"
        exit $?
        ;;

    --sim)
        REMOTE_CMD="cd $REMOTE_HW && vivado -source ./scripts/create_project.tcl -source ./scripts/run_simulation.tcl"
        ;;

    --create-project)
        REMOTE_CMD="cd $REMOTE_HW && vivado -source ./scripts/create_project.tcl"
        ;;

    gui|"")
        REMOTE_CMD="cd $REMOTE_HW && vivado"
        ;;

    *)
        echo "error: unknown mode '$MODE'" >&2
        echo "usage: $(basename "$0") [--create-project|--sim|--batch-sim]" >&2
        exit 2
        ;;
esac

echo ">>> launching Vivado on $PDP_SERVER_HOST with X11 forwarding (-Y)..."
echo "    tip: if Vivado is too slow over X11, switch to X2GO — see launch-x2go.sh"

# -Y = trusted X11 forwarding (faster than -X for heavy GUIs like Vivado).
exec ssh -Y -i "$PDP_SSH_KEY" \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    "$PDP_SERVER_USER@$PDP_SERVER_HOST" \
    "bash -lc '$REMOTE_CMD'"
