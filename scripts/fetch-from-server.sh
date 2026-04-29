#!/usr/bin/env bash
# Download files from the PDP server to this laptop via scp.
# Typical use: fetch the bitstream + .hwh + .tcl from Vivado runs so we can
# upload them to the PYNQ-Z1 through the browser.
#
# Usage:
#   ./scripts/fetch-from-server.sh <remote-path> [local-path]
#   ./scripts/fetch-from-server.sh --bitstream         # convenience: pulls the base riscy bitstream bundle
#
# Examples:
#   ./scripts/fetch-from-server.sh '~/pdp-project/hardware/vivado/riscy/riscy.runs/impl_1/riscv_wrapper.bit' ./artifacts/
#   ./scripts/fetch-from-server.sh --bitstream
#
# Tip: prefer this over dragging files through X2GO — scp is faster and scriptable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="${PDP_ARTIFACTS_DIR:-$WORKSPACE_ROOT/artifacts}"
mkdir -p "$ARTIFACTS_DIR"

SCP_ARGS=(-i "$PDP_SSH_KEY" -o ServerAliveInterval=60)

if [[ "${1:-}" == "--bitstream" ]]; then
    echo ">>> fetching the baseline bitstream bundle to $ARTIFACTS_DIR/"
    REMOTE_BASE='$HOME/pdp-project/hardware/vivado/riscy/riscy.runs/impl_1'
    REMOTE_HWH='$HOME/pdp-project/hardware/vivado/riscy/riscy.gen/sources_1/bd/riscv/hw_handoff/riscv.hwh'
    scp "${SCP_ARGS[@]}" \
        "$PDP_SERVER_USER@$PDP_SERVER_HOST:$REMOTE_BASE/riscv_wrapper.bit" \
        "$PDP_SERVER_USER@$PDP_SERVER_HOST:$REMOTE_BASE/riscv_wrapper.tcl" \
        "$PDP_SERVER_USER@$PDP_SERVER_HOST:$REMOTE_HWH" \
        "$ARTIFACTS_DIR/"
    echo ">>> done. files in $ARTIFACTS_DIR/:"
    ls -la "$ARTIFACTS_DIR/"
    exit 0
fi

if [[ $# -lt 1 ]]; then
    echo "usage: $(basename "$0") <remote-path> [local-path]" >&2
    echo "       $(basename "$0") --bitstream" >&2
    exit 2
fi

REMOTE="$1"
LOCAL="${2:-$ARTIFACTS_DIR/}"
mkdir -p "$(dirname "$LOCAL")" 2>/dev/null || true

echo ">>> scp $PDP_SERVER_USER@$PDP_SERVER_HOST:$REMOTE  ->  $LOCAL"
scp -r "${SCP_ARGS[@]}" \
    "$PDP_SERVER_USER@$PDP_SERVER_HOST:$REMOTE" "$LOCAL"
