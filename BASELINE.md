# PDP Group 24 — Measured Baseline (2026-04-24)

Raw material for the intermediate report. All numbers measured from the
unmodified gitlab repo at `pdp-project-24/` on the TU Delft server
`ce-procdesign01.ewi.tudelft.nl`, using Vivado 2024.2, shipped RTL and
shipped `.coe` files. Pipeline proven reproducible from C source
(`make soft` produces byte-identical `.coe`).

> **Canonical software baseline (team decision, 2026-06-12): 61,184 cycles.**
> This is Hruday's current measurement and is the number used on the slides and
> for every speedup figure (HW 6,260 → unroll 4,800 → parallel DOM S-box 4,104).
> The **59,560** figure below is the original 2026-04-24 measurement; it is kept
> for history but is **superseded** — the ~2.7% gap comes from a different build
> (toolchain/`main.c`), not the machine (sim cycle counts are deterministic).
> Compare all improvements against **61,184**.

---

## 1. Functional baseline — behavioural simulation

| Item | Value |
|---|---|
| Testbench | `hardware/src/simulation/zynq_tb.sv` |
| Top module | `riscv_wrapper` |
| Simulator | Vivado XSim 2024.2 |
| Run method | GUI via X2Go → `source ./scripts/run_simulation.tcl` |
| End condition | `mem_snoop_match` detects `0xDEADBEEF` at addr `0x2000` |
| **Cycles (fetch-enable → end sentinel)** | **59,560** |
| Expected ciphertext (`0x42002030…0x4200203c`) | `fba50914 714bf41f 2e25aabe aaf9080f` |
| Calculated ciphertext (`0x42002040…0x4200204c`) | `fba50914 714bf41f 2e25aabe aaf9080f` |
| Test outcome | **PASSED** |
| xsim peak memory | ~8.5 GB RSS |
| Wall-clock run time | compile 10 s + elaborate 85 s + simulate 63 s ≈ 3 min |

> **Companion baseline:** post-implementation (full `riscv_wrapper`,
> Routed) numbers captured by Rishi 2026-05-06 are in
> [`baselines/post-impl-2026-05-06/`](./baselines/post-impl-2026-05-06/README.md).
> Use OOC numbers below for "core cost"; use post-impl for "what
> ships on the FPGA".

## 2. Area + timing baseline — OOC synthesis

Run with `source ./scripts/create_project_ooc_synth.tcl`. OOC flow
synthesizes *only* the RISC-V core (`riscv_ooc_top_level_wrapper`), not
the AXI smartconnect / BRAM controllers / PS7 IP. Part forced to
`xc7z010clg400-1` for faster estimation; final bitstream targets the
PYNQ-Z1's `xc7z020clg400-1`.

### 2.1 Resource utilization

| Cell | Count | What it is |
|---|---:|---|
| LUT1 | 7 | 1-input LUTs |
| LUT2 | 369 | 2-input LUTs |
| LUT3 | 1,383 | 3-input LUTs |
| LUT4 | 516 | 4-input LUTs |
| LUT5 | 808 | 5-input LUTs |
| LUT6 | 2,608 | 6-input LUTs |
| **Total LUTs** | **5,691** | ~10.7% of xc7z020's 53,200 |
| FDCE | 2,154 | D flip-flop, clock enable, async clear |
| FDPE | 9 | D flip-flop, clock enable, async preset |
| FDRE | 361 | D flip-flop, clock enable, sync reset |
| **Total Registers** | **2,524** | ~2.4% of xc7z020's 106,400 |
| CARRY4 | 151 | Carry chain primitives (adders) |
| MUXF7 | 277 | Wide mux (7-input via two LUT6s) |
| MUXF8 | 7 | Wider mux (8-input) |
| **DSP48E1** | **5** | Used by `cv32e40p_mult` (1) + `cv32e40p_ex_stage` (4) |
| BRAM | 0 (OOC excludes instr/data memories) |

### 2.2 Timing

| Path group | Slack | Status |
|---|---:|---|
| Setup (WNS) | **+5.513 ns** | MET, 0 failing endpoints / 4,342 total |
| Hold (WHS) | +0.254 ns | MET, 0 failing endpoints / 4,342 total |
| Pulse width (WPWS) | +9.500 ns | MET, 0 failing endpoints / 2,524 total |

**Derived clock budget:** OOC constraint is 10 ns (100 MHz). Worst combinational
path = 10 − 5.513 = **4.487 ns**. Max theoretical Fmax ≈ **222 MHz**. We have
~5.5 ns of slack to "spend" on added combinational depth (e.g., an AES SBox or
MixColumns in the ALU) before timing breaks.

## 3. Toolchain provenance

| Tool | Version | Path |
|---|---|---|
| Vivado | 2024.2 | `/opt/apps/xilinx/Vivado/2024.2/bin/vivado` |
| LLVM clang | (as shipped) | `/data/mirror/llvm/build-release/bin/clang` |
| riscv32 GCC (objcopy only) | (as shipped) | `/data/mirror/riscv/bin/riscv32-unknown-elf-objcopy` |
| Target ISA | `rv32imac_zicsr` | Set in `software/Makefile` |
| ABI | `ilp32` | small-data-limit=8 |
| Optimization | `-Os -O0` | (note: both flags passed; `-O0` wins) |

## 4. Pipeline reproducibility proof

- `cd ~/pdp-project/software && make soft` regenerates `bin_files/code.coe` and `bin_files/data.coe` from `main.c` + `include/*.c`.
- `diff hardware/src/sw/mem_files/{code,data}.coe software/bin_files/{code,data}.coe` → **empty** (byte-identical).
- Shipped `.coe` backed up at `hardware/src/sw/mem_files.shipped.bak/` in case we need to revert.

## 5. Course-published numbers (reference only)

| Metric | Course PDF | Ours (measured) | Use |
|---|---:|---:|---|
| Cycles | 161,441 | 59,560 | **ours** |
| LUTs | ~6,992 | 5,691 | **ours** |
| Registers | ~2,486 | 2,524 | either (~2% difference) |
| DSPs | 23 | 5 | **ours** (course likely includes AXI infra) |
| WNS | ~+2.131 ns | +5.513 ns | **ours** (Vivado 2024.2 gives more slack) |

Always report improvements vs. our measured values, not the PDF.

## 6. What these numbers mean for the project plan

- **Cycle target**: any RTL change adding `aes32esmi`/`aes32esi` must reduce the **61,184**-cycle software baseline (see canonical note at top; was 59,560 in April).
- **Timing budget**: +5.513 ns slack is generous. Adding an SBox LUT (8→8 bit, ~2-3 ns) and partial MixColumns XOR network (~1 ns) will consume slack but should stay positive.
- **Area budget**: xc7z020 has 53,200 LUTs, we use 5,691. Area is not the binding constraint.
- **DSPs**: 5/220 used. Plenty of room if any AES variant wants finite-field multiplies (GF(2⁸)).

## 7. Benign warnings to ignore

- `WARNING: 0ns : none of the conditions were true for unique case` — time-0 X-propagation artifact from SystemVerilog `unique case`. Happens exactly twice, harmless.
- `ERROR: XILINX_RESET_PULSE_WIDTH` from `processing_system7_0` AXI VIP at 475 ns — reset best-practice check from the VIP; AES still simulates correctly.
- `WARNING: [Timing 38-242] HD.CLK_SRC ... not set` in OOC mode — no clock buffer in OOC flow; timing numbers are still valid.
- `WARNING: No cells matched 'RISCV_CORE'` at end of OOC synth → `ERROR: [Common 17-162] Invalid option value for -cells` — stale TCL query against a cell name that doesn't exist in the netlist. Synth itself completes successfully before this line.

## 8. Artifacts on the server

- Behavioral simulation DB: `hardware/vivado/riscy/riscy.sim/sim_1/behav/xsim/zynq_tb_behav.wdb`
- OOC synth checkpoint: `hardware/vivado/ooc_riscy/ooc_riscy.runs/ooc_synth/riscv_synth.dcp`
- OOC timing report: `hardware/vivado/ooc_riscy/ooc_riscy.runs/ooc_synth/ooc_timing_summary.txt`
- `.coe` backup: `hardware/src/sw/mem_files.shipped.bak/`
