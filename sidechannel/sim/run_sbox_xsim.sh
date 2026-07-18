#!/usr/bin/env bash
# ============================================================================
#  run_sbox_xsim.sh - compile + simulate the tower-field S-box exhaustive check
# ----------------------------------------------------------------------------
#  Runs inside ~/sca on ce-procdesign01. Standalone compile of the unmasked
#  tower-field S-box + the 256-input testbench. PASS criterion: every input
#  matches the FIPS 197 table.
#
#  Usage: ./sim/run_sbox_xsim.sh
# ============================================================================
set -euo pipefail

VIVADO_BIN="/opt/apps/xilinx/Vivado/2024.2/bin"
export PATH="$VIVADO_BIN:$PATH"

SCA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCA_DIR"
mkdir -p work

echo ">>> [1/3] xvlog (compile DUT + TB)"
xvlog -sv --nolog \
    rtl/aes_sbox_tower.sv \
    tb/tb_sbox_tower.sv

echo ">>> [2/3] xelab"
xelab --nolog -timescale 1ns/1ps tb_sbox_tower -s tb_sbox_tower_sim

echo ">>> [3/3] xsim"
xsim --nolog tb_sbox_tower_sim -runall
