#!/usr/bin/env bash
# ============================================================================
#  run-zkne-test-on-pynq.sh - run Hruday's hw_aes32esi/esmi self-test on PYNQ
# ----------------------------------------------------------------------------
#  Usage:
#    ./scripts/run-zkne-test-on-pynq.sh                            # defaults
#    ./scripts/run-zkne-test-on-pynq.sh <bit> <hwh> <code> <data>
#  Defaults:
#    bit  = artifacts/zkne_tower/riscv_wrapper.bit
#    hwh  = artifacts/zkne_tower/riscv.hwh
#    code = sidechannel/build/coe/code.coe
#    data = sidechannel/build/coe/data.coe
# ============================================================================
set -euo pipefail
PYNQ_IP="${PYNQ_IP:-192.168.2.119}"
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BIT="${1:-$WORKSPACE_ROOT/artifacts/zkne_tower/riscv_wrapper.bit}"
HWH="${2:-$WORKSPACE_ROOT/artifacts/zkne_tower/riscv.hwh}"
CODE="${3:-$WORKSPACE_ROOT/sidechannel/build/coe/code.coe}"
DATA="${4:-$WORKSPACE_ROOT/sidechannel/build/coe/data.coe}"

for f in "$BIT" "$HWH" "$CODE" "$DATA"; do
    [ -f "$f" ] || { echo "missing: $f" >&2; exit 1; }
done

ping -c 1 -W 2 "$PYNQ_IP" >/dev/null 2>&1 || { echo "no ping to $PYNQ_IP" >&2; exit 1; }

echo ">>> ship bitstream + matching .hwh + coes + runner"
# PYNQ requires bit and hwh to share a basename in the same dir
sshpass -p xilinx scp -o StrictHostKeyChecking=accept-new "$BIT" "xilinx@$PYNQ_IP:/tmp/zkne_tower.bit"
sshpass -p xilinx scp                                     "$HWH" "xilinx@$PYNQ_IP:/tmp/zkne_tower.hwh"
sshpass -p xilinx scp                                     "$CODE" "xilinx@$PYNQ_IP:/tmp/code.coe"
sshpass -p xilinx scp                                     "$DATA" "xilinx@$PYNQ_IP:/tmp/data.coe"
sshpass -p xilinx scp \
    "$WORKSPACE_ROOT/pynq/run_zkne_test_on_pynq.py" "xilinx@$PYNQ_IP:/tmp/"

echo ">>> execute (sudo for pynq.Overlay)"
sshpass -p xilinx ssh "xilinx@$PYNQ_IP" \
    'echo xilinx | sudo -S python3 /tmp/run_zkne_test_on_pynq.py'
