#!/usr/bin/env bash
# ============================================================================
#  run_leak_xsim.sh — compile + simulate the Zkne leakage harness (ON SERVER)
# ----------------------------------------------------------------------------
#  Runs inside ~/sca on ce-procdesign01. Compiles the AES package + DUT + the
#  leakage testbench standalone (no Vivado project needed), then runs xsim and
#  produces a CSV of power traces under ~/sca/out/.
#
#  Usage (each KEY=VALUE becomes a +plusarg for the testbench):
#    ./sim/run_leak_xsim.sh num_traces=20000 key_byte=43 tvla=0 outfile=out/cpa.csv
#    ./sim/run_leak_xsim.sh num_traces=40000 tvla=1 fixed_pt=0 outfile=out/tvla.csv
#
#  Recognised testbench plusargs:
#    num_traces seed key_byte tvla fixed_pt op bs vcd outfile
# ============================================================================
set -euo pipefail

VIVADO_BIN="/opt/apps/xilinx/Vivado/2024.2/bin"
export PATH="$VIVADO_BIN:$PATH"

SCA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # ~/sca
cd "$SCA_DIR"
mkdir -p out work

# Build the list of -testplusarg flags from KEY=VALUE positional args.
PLUSARGS=()
for kv in "$@"; do
    PLUSARGS+=(-testplusarg "$kv")
done

echo ">>> [1/3] xvlog (compile pkg + DUT + TB)"
xvlog -sv --nolog \
    rtl/cv32e40p_pkg.sv \
    rtl/cv32e40p_zkne.sv \
    tb/tb_zkne_leak.sv

echo ">>> [2/3] xelab (elaborate)"
xelab --nolog -debug typical -timescale 1ns/1ps \
    tb_zkne_leak -s tb_zkne_leak_sim

echo ">>> [3/3] xsim (run, ${#} plusarg(s))"
xsim --nolog tb_zkne_leak_sim -runall "${PLUSARGS[@]}"

echo ">>> done. CSVs in $SCA_DIR/out/:"
ls -la "$SCA_DIR/out/"
