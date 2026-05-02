# Intermediate Report — Group 24

**CESE4040 Processor Design Project, Q4 2025-2026**
**Group 24** · TU Delft · Brightspace submission window: 2026-05-04 → 2026-05-08

> **How to use this file**: This is a *prose draft* organized to match
> the Brightspace quiz rubric (a–d below). When the quiz opens on
> 2026-05-04, paste each section into the corresponding question.
> Numbers cite measurements from `BASELINE.md` and `PROFILING.md`.

---

## (a) Proposed target metric and justification

**Target metric: cycle reduction on AES-128 ECB encryption of a single
16-byte block, measured by `mem_snoop_match.CLK_COUNT` from
fetch-enable rising edge to the `0xDEADBEEF` end sentinel.**

**Quantitative target: ≥ 2× cycle reduction** versus the measured
baseline of **59,560 cycles** (i.e. final cycle count ≤ 30,000).

### Justification

1. **Cycle count is the right metric for the mandatory deliverables.**
   The course-required `aes32esmi` and `aes32esi` instructions, plus
   the LLVM loop-unroll pass, all directly target instructions executed
   per AES round. Any savings they produce are quantifiable as cycle
   deltas. Alternative metrics (LUT count, energy, register pressure)
   would either require new tooling (for energy) or be only
   second-order responses to the cycle improvements.

2. **The baseline is reproducible and stable.** `BASELINE.md` records
   59,560 cycles, with byte-identical reproducibility from C source via
   `make soft` — proving the measurement isn't dependent on any
   pre-built binary. We have OOC synthesis numbers locked in (5,691
   LUTs, 2,524 registers, 5 DSPs, WNS +5.513 ns), so any RTL change for
   `aes32esmi` can be checked against an established area/timing
   baseline as well.

3. **The 2× target is achievable with confidence margin, derived from
   measured profiling.** Dynamic profiling (`PROFILING.md` § 7) shows
   `mix_columns` accounts for **50,643 of 60,457 measured cycles
   (83.8%)**. Since `aes32esmi` collapses the inner `gf_mult` loops
   that dominate `mix_columns`, even a half-effective implementation
   captures most of those 50k cycles. The realistic projection is
   ~3.5× (PROFILING.md § 8); we set the *target* at 2× to leave
   headroom for implementation imperfections.

4. **Independent verification is possible.** Both static analysis
   (instruction counts from `objdump`) and dynamic measurement
   (`mcycle` CSR) converge on the same conclusion (mix_columns
   dominance), so the metric isn't sensitive to a single methodology.
   Any improvement we report can be cross-checked.

---

## (b) State of the art / background

### Architectural baseline

The RISCY core in this project is the
**OpenHW Group CV32E40P** — an in-order, single-issue, 4-stage RISC-V
processor implementing **RV32IMC + Zicsr + Xpulp** [1]. CV32E40P is the
hardened evolution of the PULP-Platform "RI5CY" core [2]. It has a
hardware multiplier with DSP48E1 inference, a small load/store unit
with single-port BRAM (2-cycle read latency), and a standard M-mode
performance counter set (`mcycle`, `minstret`) controlled by
`mcountinhibit` (CSR 0x320) — which the present project uses for
dynamic profiling.

### RISC-V scalar cryptography (Zkne)

The mandatory ISA extensions for this project are drawn from the
**RISC-V Scalar Cryptography Extension v1.0.1** (ratified 2022) [3],
specifically the Zkne sub-extension for AES encryption:

- **`aes32esi rd, rs1, rs2, bs`** — encrypt single round (final): extract byte `bs` from `rs2`, apply AES SBox, rotate to byte position `bs`, XOR with `rs1`.
- **`aes32esmi rd, rs1, rs2, bs`** — encrypt middle round: extract byte `bs` from `rs2`, apply AES SBox, multiply by the MixColumns matrix row, rotate to byte position `bs`, XOR with `rs1`.

These are 32-bit "T-table style" instructions: each one produces one 32-bit lane of one
round in a single cycle, replacing the ~80 RV32I instructions our
disassembly shows for the equivalent inlined `gf_mult` + SBox + XOR
sequence (`PROFILING.md` § 2). Marshall et al. [4] introduced and
analyzed exactly this design point, demonstrating ~3-4× speedups on
similar in-order cores.

### Comparable extensions

For framing context only, two non-RISC-V comparators:

- **Intel AES-NI** (introduced 2010 on Westmere): provides
  `AESENC`, `AESDEC`, `AESKEYGENASSIST`. Operates on 128-bit XMM
  registers (one full round per instruction), optimized for OoO
  superscalar cores.
- **ARMv8 cryptography extension**: provides `AESE` (single-round
  encrypt), `AESMC` (MixColumns), operating on 128-bit NEON registers.

The Zkne instructions occupy a different design point — they keep
RISC-V's narrow datapath (32-bit lanes, one instruction per output
byte-of-column) so the extension fits a small in-order core like
CV32E40P without widening any datapath.

### Compiler context

The toolchain is **LLVM clang 18+ with the RISC-V backend** built at
`/data/mirror/llvm/build-release/bin/clang`, targeting
`rv32imac_zicsr` with `-Os -O0` (the latter wins). The course requires
adding a **built-in loop-unroll pass** [5] applied to the AES middle-
round loop. LLVM already has loop-unroll machinery in `LoopUnrollPass`
and `LoopUnrollAndJamPass`; the contribution is wiring it to recognize
or be hinted at the AES loop structure once the new instructions are
emittable.

### References

1. OpenHW Group, *CV32E40P User Manual*, https://docs.openhwgroup.org/projects/cv32e40p-user-manual/
2. Gautschi et al., "Near-Threshold RISC-V Core With DSP Extensions for Scalable IoT Endpoint Devices", *IEEE TVLSI* 2017
3. RISC-V International, *RISC-V Cryptography Extensions Volume I*, v1.0.1, ratified 2022
4. Marshall, Newell, Page, Saarinen, Wolf, *"The design of scalar AES Instruction Set Extensions for RISC-V"*, IACR TCHES 2021/1492
5. *LLVM Loop Unrolling*, https://llvm.org/docs/LoopTerminology.html#loop-unrolling

---

## (c) Planned methodology and quantitative evidence

### Measurement infrastructure (already in place)

- **Behavioural simulation** in Vivado XSim 2024.2 against the full
  `riscv_wrapper` (CV32E40P core + AXI smartconnect + dual BRAM + PS7
  VIP). Cycles measured by `mem_snoop_match.CLK_COUNT` between
  fetch-enable and the `0xDEADBEEF` sentinel.
- **OOC synthesis** in Vivado for area + Fmax. Top:
  `riscv_ooc_top_level_wrapper`. Reports written to
  `vivado/ooc_riscy/ooc_riscy.runs/ooc_synth/`.
- **Static analysis** via `riscv32-unknown-elf-objdump -d` of the
  compiled `output/soft.elf`, function sizes derived from address gaps.
- **Dynamic profiling** via `mcycle` CSR reads bracketing each AES
  phase, accumulated into volatile globals, written to BRAM addresses
  `0x42002060…0x42002074`, read+printed by an extended testbench.
  Required clearing `mcountinhibit` (CSR 0x320) at the top of `main()`
  because CV32E40P resets it to all-1s (counters disabled by default).

### Baseline measurements (locked in)

| Metric | Value | Source |
|---|---:|---|
| Sim cycles | **59,560** | `BASELINE.md` § 1 |
| OOC LUTs | 5,691 | `BASELINE.md` § 2.1 |
| OOC Registers | 2,524 | `BASELINE.md` § 2.1 |
| OOC DSPs | 5 | `BASELINE.md` § 2.1 |
| OOC WNS | +5.513 ns | `BASELINE.md` § 2.2 |
| `mix_columns` share of cycles | **83.8%** (50,643) | `PROFILING.md` § 7.2 |
| `add_round_key` share | 4.7% | `PROFILING.md` § 7.2 |
| `sub_bytes` share | 4.4% | `PROFILING.md` § 7.2 |
| `expand_key` share (one-shot) | 4.0% | `PROFILING.md` § 7.2 |
| `shift_rows` share | 0.8% | `PROFILING.md` § 7.2 |
| Static-vs-dynamic agreement on top hot-spot | within 4% | `PROFILING.md` § 7.3 |

### Methodology limits (explicit, per rubric)

- **Behavioural simulation, not gate-level** — switching activity and
  energy are not modelled. We report cycle counts, not power.
- **Single test vector** — one 16-byte block with one fixed key. AES is
  data-independent in cycle count for this implementation, so this is
  representative, but we will run additional vectors before final
  submission to confirm.
- **Instrumentation overhead** — dynamic profiling adds ~897 cycles
  (1.5%) to the total; per-function totals are inflated proportionally.
  Negligible for ranking, visible in absolute totals.
- **No FPGA confirmation yet** — Phase 1 numbers are simulation-only.
  FPGA bring-up on PYNQ-Z1 is scheduled for the 2026-05-01 lab.

### Phase 2 measurement plan

1. Re-run the same simulation flow after each RTL/compiler change.
   Cycle counts comparable directly against the 59,560 baseline.
2. Re-run OOC synthesis after each RTL change. Area/timing comparable
   against 5,691 LUT / +5.513 ns WNS baseline.
3. Generate the full bitstream and verify on PYNQ-Z1 — confirms the
   simulation-projected speedup translates to silicon (sanity check
   only; no metric depends on it).
4. Repeat dynamic profiling after `aes32esmi`/`aes32esi` are wired up.
   Predicted: `mix_columns` drops from 83.8% of cycles to <10%.

### Projected outcomes (with measured anchoring)

| Scenario | Projected cycles | Speedup vs 59,560 |
|---|---:|---:|
| Mandatory deliverables only, half-effective `aes32esmi` | ~30,000 | ~2.0× (target) |
| Mandatory deliverables fully effective + minor compiler hints | ~17,000 | ~3.5× |
| Mandatory + group-specific improvement (Task 2.2, see (d)) | ~12,000 | ~5× |

The 5× upper bound assumes the group-specific improvement (Section d)
attacks the ~10% of cycles not covered by `aes32esmi`/`aes32esi`
themselves.

---

## (d) Internal task breakdown, dependencies, milestones

### Group composition

Group 24, 4 members. Names + NetIDs filled in by group consensus
before submission. Daniel Tyukov (datyukov) is responsible for repo
infrastructure (server, GitHub mirror, helper scripts) and
intermediate-report compilation; the other three teammates own the
substantive Phase 2 work as below. *(Owners TBD — to be confirmed
in our coordination meeting before 2026-05-04.)*

### Work breakdown

| ID | Subtask | Owner | Depends on | Effort | Target completion |
|---|---|---|---|---|---|
| **2.1.RTL** | Decode + execute `aes32esmi` and `aes32esi` in `cv32e40p_decoder.sv`, `cv32e40p_alu.sv`, `cv32e40p_pkg.sv`. AES SBox as a 256×8 lookup table; partial MixColumns combinational network for the four matrix coefficients (1, 2, 3, GF-multiplied). | TBD-A | — | ~30 h | 2026-05-23 |
| **2.1.LLVM-asm** | Verify GAS encoding of the new instructions. First exposure to C via inline `asm volatile` so the C source can emit them without a full LLVM rebuild. | TBD-B | 2.1.RTL | ~6 h | 2026-05-26 |
| **2.1.LLVM-builtin** | Add `__builtin_riscv_aes32esmi` / `aes32esi` intrinsics in the LLVM RISC-V backend. Requires building LLVM from source (cloning llvm-project into `$HOME` on the server because we can't write to `/data/mirror/llvm/build-release`). | TBD-B | 2.1.LLVM-asm | ~20 h | 2026-06-02 |
| **2.1.LLVM-unroll** | Configure the existing `LoopUnrollPass` to fully unroll the AES middle-round loop. Either via `-mllvm -unroll-count` flag or a small custom pass. Required as a course deliverable; modest cycle impact. | TBD-B | 2.1.LLVM-asm | ~8 h | 2026-06-02 |
| **2.1.SIM-VERIFY** | After every RTL/LLVM change: re-run baseline AES simulation, confirm `Test PASSED`, capture cycle count. Track regression cases. | TBD-C | each subtask above | continuous | continuous |
| **2.1.PYNQ** | Generate bitstream after RTL changes pass simulation. Upload to PYNQ-Z1 via Jupyter, run the AES notebook, compare wall-clock vs simulation cycles. | TBD-C | 2.1.RTL passing sim | ~6 h per iteration | 2026-06-09 |
| **2.2.GROUP-IMPROVEMENT** | Group-specific improvement (see options below). To be picked at our 2026-05-04 meeting. | TBD-D + group | 2.1.RTL passing | ~25 h | 2026-06-09 |
| **2.3.REPORT** | Final report writeup, slides, demo script, archive of RTL + LLVM mods + scripts. | All | all above | ~15 h shared | 2026-06-12 |

### Group-specific improvement (Task 2.2) — candidates and our choice

The course allows the group to pick a second improvement axis. Our
candidates, ranked by predicted impact given the measured profile:

1. **Custom LLVM "AES vectorization" pass** that fuses the four
   per-column `aes32esmi` calls into a single block, eliminating
   inter-call register spills and exposing the result chain to the
   instruction scheduler. Predicted: additional 10–20% cycle reduction.
2. **Side-channel resistance** — timing-equalize the SBox path so
   memory-access patterns do not depend on key bytes. Important for
   AES as a security primitive, easy to motivate in the report.
   Predicted: zero cycle improvement (potentially small regression);
   but adds the security dimension as a measurement axis.
3. **Memory-footprint reduction** — collapse the 176-byte expanded
   `round_keys` array into compile-time-derived state, reducing data
   BRAM usage. Predicted: small cycle reduction (~1-2%) but a clear
   "footprint" metric.

**Our intended pick: option 1 (custom LLVM vectorization pass)** —
piggybacks on the mandatory work, has direct cycle impact, and
demonstrates the LLVM expertise the course wants to develop. Final
choice confirmed at the 2026-05-04 meeting.

### Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Rebuilding LLVM in `$HOME` runs out of disk on the shared server | medium | high (blocks 2.1.LLVM-builtin) | Start with the inline-asm path (2.1.LLVM-asm) which doesn't need a rebuild; only attempt full LLVM rebuild after early measurements confirm it's worth the effort |
| Decoder conflicts with existing Xpulp custom encodings in CV32E40P | low | medium | Allocate `aes32esmi`/`aes32esi` to the OP_CUSTOM_0 opcode space (RISC-V reserves it explicitly for ISA extensions); cross-check against `cv32e40p_pkg.sv` opcodes |
| Adding combinational SBox+MixColumns to the ALU eats WNS slack | medium | medium | We have +5.513 ns headroom (BASELINE.md § 2.2); after first synth iteration, if WNS goes negative, pipeline the AES op across two cycles |
| Server overload during deadline week | high | low | Pre-build bitstream early (Task #7 before Fri 2026-05-01 lab); intermediate report doesn't depend on FPGA |
| Teammate availability gaps | medium | medium | Tasks 2.1.LLVM-asm and 2.1.LLVM-builtin are independent of 2.1.RTL — work can proceed in parallel |

### Milestones

- **2026-05-04 meeting**: confirm metric, group-specific improvement choice, owner assignments. Lock the report content for Brightspace submission.
- **2026-05-08 23:59**: intermediate report submitted (this document → Brightspace).
- **2026-05-23**: `aes32esmi`/`aes32esi` decoded + executed in RTL, simulation passes.
- **2026-06-02**: full LLVM toolchain emits the new instructions; loop-unroll pass in place.
- **2026-06-09**: group-specific improvement merged; FPGA verification complete.
- **2026-06-12**: final source archive + presentation slides submitted.
- **Weeks 25–26**: 60-min final slot (presentation + demo + Q&A).

---

## Source documents underpinning this report

All measurements cited here are reproducible from the artifacts in this
repo:

- [`CLAUDE.md`](./CLAUDE.md) — project context, server setup, toolchain paths
- [`BASELINE.md`](./BASELINE.md) — measured baseline (cycles, area, timing)
- [`PROFILING.md`](./PROFILING.md) — static + dynamic profiling, methodology
- [`PROGRESS.md`](./PROGRESS.md) — what's done, what's next, deadlines
- [`profiling-instrumentation/`](./profiling-instrumentation/) — instrumented `main.c` and `zynq_tb.sv` source snapshots
- `pdp-project-24/` (git submodule → GitLab) — RTL + C sources, course-tracked
