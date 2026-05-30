#!/usr/bin/env bash
# ============================================================================
#  run_dom_leak_xsim.sh - simulate the leakage rig on the DOM-masked S-box
# ----------------------------------------------------------------------------
#  Runs inside ~/sca on ce-procdesign01. Compiles the DOM module + leakage TB,
#  then runs xsim with plusargs forwarded.
#
#  Usage:
#    ./sim/run_dom_leak_xsim.sh num_traces=20000 key_byte=43 tvla=0 outfile=out/dom_cpa.csv
#    ./sim/run_dom_leak_xsim.sh num_traces=40000 tvla=1 fixed_pt=0 key_byte=43 outfile=out/dom_tvla.csv
# ============================================================================
set -euo pipefail

VIVADO_BIN="/opt/apps/xilinx/Vivado/2024.2/bin"
export PATH="$VIVADO_BIN:$PATH"

SCA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCA_DIR"
mkdir -p out work

PLUSARGS=()
for kv in "$@"; do
    PLUSARGS+=(-testplusarg "$kv")
done

echo ">>> [1/3] xvlog (DOM DUT + leakage TB)"
xvlog -sv --nolog \
    rtl/aes_sbox_tower_dom.sv \
    tb/tb_zkne_leak_dom.sv

echo ">>> [2/3] xelab"
xelab --nolog -debug typical -timescale 1ns/1ps \
    tb_zkne_leak_dom -s tb_zkne_leak_dom_sim

echo ">>> [3/3] xsim (${#} plusarg(s))"
xsim --nolog tb_zkne_leak_dom_sim -runall "${PLUSARGS[@]}"

echo ">>> done. CSVs in $SCA_DIR/out/:"
ls -la "$SCA_DIR/out/" | tail -6
