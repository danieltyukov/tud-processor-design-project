#!/usr/bin/env bash
# ============================================================================
#  push-sca.sh - copy the side-channel leakage harness to the server (~/sca)
# ----------------------------------------------------------------------------
#  Pushes the standalone unit testbench + run script + the two DUT RTL files
#  (cv32e40p_pkg.sv, cv32e40p_zkne.sv) from the local sidechannel-dom branch
#  into ~/sca on ce-procdesign01. The unit sim does NOT need the Vivado project
#  or the server's git repo - just these files compiled standalone with xsim.
#
#  Usage:
#    ./scripts/push-sca.sh
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SCA_LOCAL="$WORKSPACE_ROOT/sidechannel"
RTL_DIR="$WORKSPACE_ROOT/pdp-project-24/hardware/src/design/riscy"

SSH_ARGS=(-i "$PDP_SSH_KEY" -o ServerAliveInterval=60)
DEST="$PDP_SERVER_USER@$PDP_SERVER_HOST"

echo ">>> creating ~/sca tree on the server"
ssh "${SSH_ARGS[@]}" "$DEST" 'mkdir -p ~/sca/rtl ~/sca/tb ~/sca/sim ~/sca/analysis ~/sca/out ~/sca/work'

echo ">>> copying DUT RTL (pkg + zkne)"
scp "${SSH_ARGS[@]}" \
    "$RTL_DIR/include/cv32e40p_pkg.sv" \
    "$RTL_DIR/cv32e40p_zkne.sv" \
    "$DEST:sca/rtl/"

echo ">>> copying testbench + run script + analysis"
scp "${SSH_ARGS[@]}" "$SCA_LOCAL/tb/tb_zkne_leak.sv"   "$DEST:sca/tb/"
scp "${SSH_ARGS[@]}" "$SCA_LOCAL/sim/run_leak_xsim.sh" "$DEST:sca/sim/"
scp "${SSH_ARGS[@]}" "$SCA_LOCAL"/analysis/*.py        "$DEST:sca/analysis/"

ssh "${SSH_ARGS[@]}" "$DEST" 'chmod +x ~/sca/sim/run_leak_xsim.sh'

echo ">>> done. server ~/sca contents:"
ssh "${SSH_ARGS[@]}" "$DEST" 'ls -R ~/sca | head -40'
