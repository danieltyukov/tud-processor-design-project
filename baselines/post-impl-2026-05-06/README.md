# Post-Implementation Baseline — 2026-05-06

Reports captured by **Rishi** on his Windows laptop (Vivado 2024.2,
host `Rishi-TDW`) on **2026-05-06 14:27 local time**, against the
**unmodified** `riscv_wrapper` design after a full place-and-route
(`Design State: Routed`). Files were not pushed to git at the time, so
they were transferred over chat and parked here.

## Files

```
baselines/post-impl-2026-05-06/
├── README.md                          ← this file
├── reports/
│   ├── utilization_report.txt         ← post-impl `report_utilization`
│   ├── timing_report.txt              ← post-impl `report_timing_summary` (full, ~400 KB)
│   └── power_power_1.txt              ← post-impl `report_power` (vectorless)
└── screenshots/
    ├── utilization_summary.png        ← Vivado IDE Utilization tab (Hierarchy view)
    ├── power_summary.png              ← Vivado IDE Power tab (Summary)
    └── timing_summary.png             ← Vivado IDE Timing tab (Design Timing Summary)
```

## What this baseline measures (scope is different from OOC!)

This is the **full implemented design** on `xc7z020clg400-1` (PYNQ-Z1):
the CV32E40P core **plus** AXI smartconnect + BRAM controllers + the
hardened PS7 (Cortex-A9) + clock infrastructure. Numbers therefore
include the wrapper, not just the core.

The `BASELINE.md` numbers we used in the report draft are **OOC**
(Out-Of-Context) synthesis of just the CV32E40P core with a synthetic
100 MHz constraint. Both are valid; they answer different questions.

| Question | Use these numbers |
|---|---|
| "What does the AES-bound *core logic* cost?" | OOC: 5,691 LUTs / 2,524 regs / +5.513 ns WNS @100 MHz |
| "What ships on the FPGA, end-to-end?" | Post-impl: 10,171 LUTs / 8,522 regs / +28.306 ns WNS @20 MHz |

## Numbers extracted from the reports

### Utilization (`utilization_report.txt`, design = `riscv_wrapper`, routed)

| Resource | Used | Available | Util % |
|---|---:|---:|---:|
| Slice LUTs (combined) | **10,171** | 53,200 | 19.12 % |
| - LUT as Logic | 9,303 | 53,200 | 17.49 % |
| - LUT as Memory (Distributed RAM + SR) | 868 | 17,400 | 4.99 % |
| Slice Registers | **8,522** | 106,400 | 8.01 % |
| Slices (occupied) | 3,573 | 13,300 | 26.86 % |
| F7 Muxes / F8 Muxes | 303 / 7 | 26,600 / 13,300 | <1 % |
| Block RAM Tile (RAMB36E1) | **16** | 140 | 11.43 % |
| DSP48E1 | **5** | 220 | 2.27 % |
| BUFGCTRL | 1 | 32 | 3.13 % |
| Bonded IOPADs (PS7) | 130 | 130 | 100 % |

Primitive breakdown (from § 8): 5,960 FDRE + 2,184 FDCE + 370 FDSE + 8 FDPE = 8,522 FFs;
4,403 LUT6 + 2,985 LUT3 + 1,680 LUT5 + 1,619 LUT4 + 899 LUT2 + 310 LUT1 = 11,896 raw LUTs (10,171 after combining).

### Timing (`timing_report.txt`, design = `riscv_wrapper`, routed)

| Metric | Value | Status |
|---|---:|:---:|
| Clock `clk_fpga_0` period (constraint) | **50.000 ns** (20 MHz) | — |
| Worst Negative Slack (WNS, Setup) | **+28.306 ns** | MET |
| Total Negative Slack (TNS) | 0.000 ns | MET |
| Worst Hold Slack (WHS) | +0.022 ns | MET (very tight) |
| Total Hold Slack (THS) | 0.000 ns | MET |
| Worst Pulse Width Slack (WPWS) | +23.750 ns | MET |
| Failing endpoints (Setup / Hold / PW) | 0 / 0 / 0 | MET |
| Total endpoints (Setup) | 28,862 | — |

> *"All user specified timing constraints are met."*

**Implied Fmax (full implemented design, post-impl):**
```
F_max ≈ 1 / (T_clk - WNS) = 1 / (50 - 28.306) ns = 1 / 21.694 ns ≈ 46.1 MHz
```

So the design ships at 20 MHz with ~58 % of the cycle as slack, and
could in principle be re-constrained up to ~46 MHz before timing
breaks. (vs. core-only OOC at ~222 MHz — the 5× gap is mostly the
extra fabric routing and PS7-bridge endpoints.)

Worst-path destinations (from `timing_report.txt` lines 220–730) are
clustered around the multiplier operand registers in the ID stage:
`riscv_top_bram_0/inst/riscv_core/id_stage_i/mult_operand_a_ex_o_reg[19]`,
`alu_operand_a/b_ex_o_reg[19]`, etc. These are the exact paths
Phase 2's `aes32esmi`/`aes32esi` will have to share — flag for
TBD-A (RTL owner).

### Power (`power_power_1.txt`, vectorless, Confidence: Medium)

| Component | Power |
|---|---:|
| **Total On-Chip Power** | **1.419 W** |
| - Dynamic | 1.283 W (90 %) |
| - Device Static | 0.136 W (10 %) |
| Junction Temperature | 41.4 °C (max ambient 68.6 °C, ΘJA 11.5 °C/W) |
| Confidence Level | Medium (vectorless: <25 % of internal nodes specified) |

Dynamic power breakdown:

| Block | Power | % of dynamic |
|---|---:|---:|
| **PS7** (hardened Cortex-A9 + DDR controller) | **1.256 W** | 95 % |
| smartconnect_0 | 0.012 W | 1 % |
| Signals | 0.007 W | 0.5 % |
| Slice Logic (LUTs + FFs + carry + SR + muxes) | 0.006 W | 0.5 % |
| Clocks | 0.006 W | 0.5 % |
| Block RAM | 0.006 W | 0.5 % |
| `riscv_top_bram_0` (CV32E40P core wrapper) | 0.006 W | 0.5 % |
| `instr_mem` / `data_mem` | 0.003 / 0.004 W | <1 % |
| DSPs | <0.001 W | <0.1 % |

**Important framing for the report:** the headline 1.419 W number is
**dominated by the always-on PS7** (95 % of dynamic). Power
optimizations targeting the PL (where our AES improvements live) have
a hard ceiling around **0.027 W of dynamic switching power** in the
core+memory subtree. Reporting "X% reduction in PL dynamic power" or
"reduction in core BRAM accesses" is a more honest framing than total
on-chip power.

## What this covers vs. what is left (re: 2026-05-08 intermediate report)

### ✅ Now covered by these artifacts

- **(c) Methodology**: we now have *implemented*, not just OOC, area + timing + power numbers.
- **Area baseline**: 10,171 LUTs / 8,522 FFs / 16 BRAMs / 5 DSPs (full design).
- **Power baseline**: 1.419 W total on-chip; usable for Rishi's "side-channel resistance" axis (need power-trace plots later but the baseline number exists).
- **Timing baseline**: design closes at 20 MHz with 28.3 ns slack, max ~46 MHz.
- **Hot-path identification**: ID-stage multiplier operand registers — useful when we wire `aes32esmi` into the ALU.

### ⚠️ Still missing for tonight's quiz

- **Owner names** for the work-breakdown table (REPORT_INTERMEDIATE.md:208, 213–221). Rishi's WhatsApp message confirms the **scope split**:
  - Rishi → side-channel resistance investigation (Task 2.2 group-specific improvement candidate).
  - "Someone" → area / power / latency / throughput surveys.
  - Daniel → repo + report compilation.
  - 4th teammate → still unassigned.
- **Group-specific improvement final pick**. Rishi's message reframes Task 2.2 from *"custom LLVM vectorization pass"* (current draft REPORT_INTERMEDIATE.md:242) to *"side-channel resistance"*. The report needs to say which one, with justification — they're very different metrics.
- **Confirmation the 2026-05-04 meeting happened** and that the four candidate axes (area / power / latency / throughput) are *surveys*, not chosen improvements.

### ⏭ Not blocking the report (Phase 2 prerequisites)

- PYNQ-Z1 home connectivity check (PROGRESS.md:68).
- Bitstream pull (`./scripts/fetch-from-server.sh --bitstream`) — `artifacts/` for the bitstream is still empty; Rishi may already have one on his laptop, but it's not in our shared workspace yet.
- FPGA bring-up at the 2026-05-01 lab — PROGRESS.md still has it unchecked. Need to confirm this happened.

## Reproduction commands (for next time)

To regenerate these reports on the server (after `gen_bitstream.tcl`
or `run_synth_impl.tcl` finishes):

```tcl
# In Vivado Tcl console, after impl_1 is open
open_run impl_1
report_utilization -file utilization_report.txt
report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -max_paths 10 -input_pins -routable_nets \
    -file timing_report.txt
report_power -file power_power_1.txt
```

Then `./scripts/fetch-from-server.sh '~/pdp-project/hardware/vivado/riscy/*.txt' baselines/post-impl-<date>/reports/`.
