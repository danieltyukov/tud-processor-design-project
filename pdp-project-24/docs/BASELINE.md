# Measured Baseline

All numbers measured from the unmodified RISCY design (Vivado 2024.2,
shipped RTL and shipped `.coe` files). The C-to-COE-to-simulation pipeline is
reproducible from source: `make soft` produces byte-identical `.coe` outputs.

**Canonical software baseline: 61,184 cycles.** This is the reference figure
used for all speedup measurements (hardware AES 6,260 cycles, loop-unrolled
4,800, parallel DOM S-box 4,104).

## 1. Functional baseline (behavioural simulation)

| Item | Value |
|---|---|
| Top module | `riscv_wrapper` |
| Simulator | Vivado XSim 2024.2 |
| End condition | `mem_snoop_match` detects `0xDEADBEEF` at addr `0x2000` |
| Cycles (fetch-enable to end sentinel) | 61,184 |
| Expected ciphertext | `fba50914 714bf41f 2e25aabe aaf9080f` |
| Calculated ciphertext | `fba50914 714bf41f 2e25aabe aaf9080f` |
| Test outcome | PASSED |

A companion post-implementation snapshot (full routed `riscv_wrapper`) gives
the resource and timing figures for what actually ships on the FPGA. The OOC
numbers below capture core-only cost.

## 2. Area and timing baseline (OOC synthesis)

The out-of-context (OOC) flow synthesizes only the RISC-V core
(`riscv_ooc_top_level_wrapper`), excluding the AXI smartconnect, BRAM
controllers, and PS7 IP. The part is forced to `xc7z010clg400-1` for faster
estimation; the final bitstream targets the PYNQ-Z1's `xc7z020clg400-1`.

### 2.1 Resource utilization

| Cell | Count | What it is |
|---|---:|---|
| LUT1 | 7 | 1-input LUTs |
| LUT2 | 369 | 2-input LUTs |
| LUT3 | 1,383 | 3-input LUTs |
| LUT4 | 516 | 4-input LUTs |
| LUT5 | 808 | 5-input LUTs |
| LUT6 | 2,608 | 6-input LUTs |
| Total LUTs | 5,691 | ~10.7% of xc7z020's 53,200 |
| FDCE | 2,154 | D flip-flop, clock enable, async clear |
| FDPE | 9 | D flip-flop, clock enable, async preset |
| FDRE | 361 | D flip-flop, clock enable, sync reset |
| Total Registers | 2,524 | ~2.4% of xc7z020's 106,400 |
| CARRY4 | 151 | Carry chain primitives (adders) |
| MUXF7 | 277 | Wide mux (7-input via two LUT6s) |
| MUXF8 | 7 | Wider mux (8-input) |
| DSP48E1 | 5 | `cv32e40p_mult` (1) plus `cv32e40p_ex_stage` (4) |
| BRAM | 0 | OOC excludes instruction/data memories |

### 2.2 Timing

| Path group | Slack | Status |
|---|---:|---|
| Setup (WNS) | +5.513 ns | MET, 0 failing endpoints / 4,342 total |
| Hold (WHS) | +0.254 ns | MET, 0 failing endpoints / 4,342 total |
| Pulse width (WPWS) | +9.500 ns | MET, 0 failing endpoints / 2,524 total |

**Derived clock budget:** the OOC constraint is 10 ns (100 MHz). The worst
combinational path is 10 - 5.513 = 4.487 ns, giving a maximum theoretical Fmax
of about 222 MHz. There is roughly 5.5 ns of slack to spend on added
combinational depth (for example an AES S-box or MixColumns in the ALU) before
timing breaks.

## 3. Toolchain provenance

| Tool | Version |
|---|---|
| Vivado | 2024.2 |
| Target ISA | `rv32imac_zicsr` |
| ABI | `ilp32` (small-data-limit=8) |
| Optimization | `-Os -O0` (`-O0` wins) |

## 4. What these numbers mean for the project plan

- **Cycle target:** any RTL change adding `aes32esmi`/`aes32esi` must reduce
  the 61,184-cycle software baseline.
- **Timing budget:** +5.513 ns slack is generous. Adding an S-box LUT
  (8-to-8 bit, ~2 to 3 ns) and a partial MixColumns XOR network (~1 ns) will
  consume slack but should stay positive.
- **Area budget:** area is not the binding constraint (5,691 of 53,200 LUTs).
- **DSPs:** 5 of 220 used, leaving room for any AES variant that wants
  finite-field multiplies in GF(2⁸).
