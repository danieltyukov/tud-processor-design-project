#!/usr/bin/env bash
# ============================================================================
#  run_sbox_dom_xsim.sh - compile + simulate the DOM-masked S-box equivalence test
# ----------------------------------------------------------------------------
#  Runs inside ~/sca on ce-procdesign01. PASS criterion: for every (input,
#  mask, random) combination tested, out_share0 XOR out_share1 equals the
#  standard AES S-box of input.
# ============================================================================
set -euo pipefail

VIVADO_BIN="/opt/apps/xilinx/Vivado/2024.2/bin"
export PATH="$VIVADO_BIN:$PATH"

SCA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCA_DIR"
mkdir -p work

echo ">>> [1/3] xvlog (DOM DUT + TB)"
xvlog -sv --nolog \
    rtl/aes_sbox_tower_dom.sv \
    tb/tb_sbox_tower_dom.sv

echo ">>> [2/3] xelab"
xelab --nolog -timescale 1ns/1ps tb_sbox_tower_dom -s tb_sbox_tower_dom_sim

echo ">>> [3/3] xsim"
xsim --nolog tb_sbox_tower_dom_sim -runall
