#!/usr/bin/env bash
# ============================================================================
#  run-zkne-test-on-pynq.sh - run Hruday's hw_aes32esi/esmi self-test on PYNQ
# ----------------------------------------------------------------------------
#  Uploads a bitstream + .coe pair and runs the Zkne self-test, which exercises
#  the new aes32esi/aes32esmi RTL on real silicon and compares hw outputs to a
#  software reference. PASS criterion: 0x2008 == 0xCAFEBABE.
#
#  Usage:
#    ./scripts/run-zkne-test-on-pynq.sh <bit> <code.coe> <data.coe>
#  Defaults (post-build):
#    bit  = artifacts/zkne_tower/riscv_wrapper.bit
#    code = sidechannel/build/coe/code.coe
#    data = sidechannel/build/coe/data.coe
# ============================================================================
set -euo pipefail
PYNQ_IP="${PYNQ_IP:-192.168.2.119}"
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BIT="${1:-$WORKSPACE_ROOT/artifacts/zkne_tower/riscv_wrapper.bit}"
CODE="${2:-$WORKSPACE_ROOT/sidechannel/build/coe/code.coe}"
DATA="${3:-$WORKSPACE_ROOT/sidechannel/build/coe/data.coe}"

for f in "$BIT" "$CODE" "$DATA"; do
    [ -f "$f" ] || { echo "missing: $f" >&2; exit 1; }
done

echo ">>> sanity: board reachable?"
ping -c 1 -W 2 "$PYNQ_IP" >/dev/null 2>&1 || { echo "no ping to $PYNQ_IP" >&2; exit 1; }

echo ">>> ship bitstream + coes + runner to PYNQ"
sshpass -p xilinx scp -o StrictHostKeyChecking=accept-new \
    "$BIT" "xilinx@$PYNQ_IP:/tmp/zkne_tower.bit"
sshpass -p xilinx scp \
    "$CODE" "xilinx@$PYNQ_IP:/tmp/code.coe"
sshpass -p xilinx scp \
    "$DATA" "xilinx@$PYNQ_IP:/tmp/data.coe"
sshpass -p xilinx scp \
    "$WORKSPACE_ROOT/pynq/run_zkne_test_on_pynq.py" "xilinx@$PYNQ_IP:/tmp/"

echo ">>> execute (sudo needed for pynq.Overlay)"
sshpass -p xilinx ssh "xilinx@$PYNQ_IP" \
    'echo xilinx | sudo -S python3 /tmp/run_zkne_test_on_pynq.py'
