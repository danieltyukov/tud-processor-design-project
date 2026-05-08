# Intermediate Report: Final Answers

CESE4040 Processor Design Project, Q4 2025-2026, Group 24.
Submission window: 2026-05-04 to 2026-05-08 23:59 (one Brightspace
submission per group). Paste each section into the matching
question.

Group 24 has 5 members: Daniel Tyukov, Rishi, Vishnu Karthik,
Hruday Gowda, Sathya. (Confirm Sathya's surname before submission.)

---

## Q1. What extension(s) and improvement(s) are you planning to implement?

We will implement four things.

**1. The Zkne instructions `aes32esi` and `aes32esmi` in the RISCY
core.** From RISC-V Scalar Cryptography v1.0.1 (2022). Each does one
byte of work: extract a byte, run the AES S-box, rotate to position,
XOR into a destination register. `aes32esmi` also applies one
MixColumns row and is used for middle rounds. `aes32esi` skips
MixColumns and is used for the final round. We add them inside the
existing CV32E40P ALU, decoder, and packed types. Target: single
cycle wherever timing slack allows.

**2. A built-in LLVM loop-unroll pass on the AES middle-round
loop.** Once (1) is in place, each output word becomes a
four-instruction `aes32esmi` chain. Unrolling the surrounding loop
removes loop overhead and lets the scheduler interleave the chains.
We use LLVM's existing `LoopUnrollPass` via `-mllvm -unroll-count`,
a `#pragma unroll`, or a small custom pass, whichever is easiest in
the LLVM build on the server.

**3. A custom super-instruction that fuses one AES middle-round
column into a single op.** The Zkne instructions only do one byte
at a time. One full output word still takes four chained
`aes32esmi` calls, so a middle round needs sixteen, and a full
encryption needs 144. We add one custom RV32 instruction (under the
`custom-0` opcode space) that takes the four state-word source
registers and produces one output word in one cycle (or one
pipelined burst). This collapses the 144 instructions to 36. The
idea is from Pan et al. (2021), "A Lightweight AES Coprocessor
Based on RISC-V Custom Instructions". We keep it instruction-level:
no DMA, no CBC orchestration in hardware.

**4. A side-channel-resilient variant using Domain-Oriented
Masking.** Following Kassimi, Aljuffri, Larmann, Hamdioui, Taouil
(2026), "Secure Implementation of RISC-V's Scalar Cryptography
Extension Set". The paper is from our department; Vishnu is in
contact with Prof. Mottah Taouil (senior author) for guidance. The
protected variant masks the AES datapath so intermediate values do
not reveal key-dependent switching. We build it as a separate RTL
track in parallel with (3) and validate it on its own terms (TVLA,
CPA, key-rank).

(3) and (4) are independent. (3) makes AES faster. (4) makes AES
safe to use in hardware that an attacker can probe. They ship as
separate code paths so we can work on them in parallel.

---

## Q2. What metrics will be used to evaluate the final design?

Primary metric: **cycle count for AES-128 ECB encryption of one
16-byte block**, measured in behavioural simulation by
`mem_snoop_match.CLK_COUNT` from fetch-enable to the `0xDEADBEEF`
end sentinel. Baseline 59,560 cycles. We use cycles, not wall-clock,
because the FPGA and sim clocks are decoupled and cycles are clean
across RTL changes.

Track 1 (mandatory + super-instruction):

- Cycle count, per change, against 59,560.
- Functional correctness: ciphertext must equal `fba50914 714bf41f
  2e25aabe aaf9080f`.
- `mix_columns` share of cycles, from `mcycle` CSR brackets. Baseline
  83.8 %. Target after (1)+(2): under 10 %. After (3): lower still.
- Area in LUTs and registers, both core-only (OOC) and full design
  (post-impl). Baseline 5,691 / 2,524 OOC, 10,171 / 8,522 post-impl.
- Worst Negative Slack in OOC and post-impl. Baseline +5.513 ns OOC
  at 100 MHz, +28.306 ns post-impl at 20 MHz.
- Total on-chip power from `report_power`. Baseline 1.419 W (95 %
  is the always-on PS7).

Track 2 (side-channel):

- TVLA t-values on simulated power traces (Hamming-distance from
  `.vcd`). Threshold ∣t∣ < 4.5 (Kassimi et al.). Unprotected should
  fail by a wide margin; protected should pass.
- CPA correlation peaks per round-key byte. Unprotected: clear peaks
  after a few thousand traces. Protected: no clear peaks within our
  trace budget.
- Key-rank: trace count needed to push the correct key's rank below
  threshold. Higher is better.
- Power with switching activity from a `.saif` file (not vectorless).
  The masked datapath increases power slightly per Kassimi et al.

Each metric reported as absolute value plus delta against the
unmodified baseline. Realistic projection from our profiling: about
5x cycle reduction (about 12,000 cycles) once the mandatory and
super-instruction tracks land. Target set at 2x (about 30,000
cycles) for honest headroom.

---

## Q3. Why have you chosen for these extension(s) / improvement(s)?

The mandatory items are required, but they're also the right
starting point on the merits. Dynamic profiling on the unmodified
system shows `mix_columns` is 83.8 % of cycles, with an inner
software loop the compiler has already inlined. Replacing those
loops with `aes32esmi` collapses the per-byte software cost by an
order of magnitude. Loop-unrolling on top removes the remaining
overhead and lets the scheduler interleave the four-`aes32esmi`
chains.

We chose the super-instruction for three reasons. First, AES is a
real workload. Embedded systems doing TLS, secure boot, or sensor
authentication run this exact path, so per-block cost shows up as
either lower latency or lower energy per packet. Second, even with
Zkne in place, one output word still costs four chained `aes32esmi`
calls (16 per middle round, 144 per encryption); folding each
chain into one instruction reduces the dynamic instruction count
4x and removes register-file traffic between the four steps.
Third, Pan et al. reported 25-38 % runtime gain with a similar
strategy on a smaller in-order core. Our version is narrower (no
DMA, no CBC handling), so we expect a smaller gain than they did,
but still material on top of `aes32esmi` alone.

We chose the side-channel track for two reasons. AES hardware
without side-channel protection is broken in any setting where the
attacker can measure power or EM emissions: IoT nodes, smart cards,
secure elements. Kassimi et al. report only +0.39 % area and 0 %
runtime overhead with proper scheduling, so a well-engineered final
design should have it. The second reason is access: the paper is
from our department and Vishnu can ask the senior author about
methodology directly.

The validation methodology for track 2 is where we have to be
careful. The paper used a ChipWhisperer rig and we don't have one.
We extract power traces from `.vcd` waveforms using a
Hamming-distance leakage model and run TVLA and CPA in software.
This is a simulation-based assessment, not a real-silicon
measurement, and we report it as such. The other limitation is
core mismatch: Kassimi integrated DOM into CV32E40S; we have
CV32E40P. Same Zkne semantics, different surrounding pipeline, so
we expect non-trivial integration work on top of porting the
masking logic.

---

## Q4. Methodology: tasks, ownership, integration / baseline / validation

We split the five of us into three sub-teams (agreed 2026-05-08):

- **RTL team (2 people).** Zkne instruction RTL, super-instruction
  RTL, integration into the CV32E40P pipeline, OOC and post-impl
  synthesis loop.
- **Validation team (2 people).** Side-channel validation
  framework, the DOM-protected RTL track, the benchmark suite.
  Lighter weeks during early RTL bring-up; joins the other teams
  during that window.
- **Compiler team (1 person).** LLVM intrinsics, loop-unroll pass,
  compiler support for the super-instruction.

Split is provisional and we expect to rebalance as people hit or
unblock subtasks.

**A) Integration**

| ID | Task | Team | Effort |
|---|---|---|---:|
| A1 | `aes32esi` decode + execute in `cv32e40p_decoder.sv`, `cv32e40p_alu.sv`, `cv32e40p_pkg.sv` | RTL | ~15 h |
| A2 | `aes32esmi` decode + execute in the same files | RTL | ~20 h |
| A3 | Verify GAS encoding; expose to C via `asm volatile` (no LLVM rebuild needed) | Compiler | ~6 h |
| A4 | `__builtin_riscv_aes32esi`/`aes32esmi` intrinsics in LLVM RISC-V backend; rebuild LLVM in `$HOME` | Compiler | ~20 h |
| A5 | Wire LLVM `LoopUnrollPass` to fully unroll the middle-round loop | Compiler | ~8 h |
| A6 | Super-instruction RTL (custom-0 opcode, fused middle-round word) | RTL | ~25 h |
| A7 | Super-instruction compiler support: LLVM intrinsic + C glue | Compiler | ~10 h |
| A8 | SCA validation framework: `.vcd` extract, Hamming-distance traces, TVLA/CPA/key-rank scripts | Validation | ~25 h |
| A9 | DOM-protected `aes32esi`/`aes32esmi`: masked SBox, masked partial MixColumns, build switch | Validation | ~30 h |
| A10 | Compiler support for protected variant: scheduling-aware emission | Compiler | ~10 h |

**B) Baseline (mostly done in Phase 1)**

| ID | Task | Team | Status |
|---|---|---|---|
| B1 | Cycle baseline from sim (`mem_snoop_match.CLK_COUNT`) | RTL | done. 59,560 cycles, ciphertext PASSED, see `BASELINE.md` |
| B2 | OOC synthesis baseline | RTL | done. 5,691 LUTs / 2,524 regs / 5 DSPs / WNS +5.513 ns |
| B3 | Post-impl baseline (full `riscv_wrapper`, routed) | RTL | done 2026-05-06. 10,171 LUTs / 8,522 regs / 16 BRAMs / 5 DSPs / +28.306 ns @ 20 MHz / 1.419 W. See `baselines/post-impl-2026-05-06/` |
| B4 | Static profiling from `objdump -d` | Validation | done. `PROFILING.md` § 1-6, `mix_columns` ~88 % static |
| B5 | Dynamic profiling via `mcycle` CSR brackets | Validation | done 2026-05-02. `mix_columns` 83.8 % measured, cross-validates static |

**C) Validation and measurements**

| ID | Task | Team | When |
|---|---|---|---|
| C1 | Re-run baseline AES sim after every RTL change. Confirm `Test PASSED`, record cycles, diff against 59,560 | Validation | continuous |
| C2 | Re-run OOC synth, capture LUT/reg/DSP delta and WNS impact | RTL | continuous |
| C3 | Generate full bitstream after each clean sim+synth pair (`gen_bitstream.tcl`). Pipeline already proven; we built one on 2026-05-08 | RTL | per iteration |
| C4 | Upload to PYNQ-Z1, run `base_riscy.ipynb`, confirm wall-clock ciphertext matches sim | RTL | per iteration |
| C5 | Re-run dynamic profiling after `aes32esmi` lands. Confirm `mix_columns` drops below 10 % | Validation | once per integration milestone |
| C6 | Final benchmark: cycle count + ciphertext on multiple AES test vectors (not just shipped one) | Validation | end of Phase 2 |
| C7 | TVLA on simulated traces from unprotected baseline. Should fail (must show leakage) to prove the framework works | Validation | week 5 |
| C8 | TVLA + CPA + key-rank on simulated traces from protected variant. Should pass at ∣t∣ < 4.5 | Validation | week 7 |
| C9 | Final write-up, slides, demo, archive | All 5 | last week |

Order: B (mostly done) → A1, A2 (parallel) → A3 → A4, A5 (parallel) →
A6, A7 for track 1. In parallel: A8 → A9 → A10 → C7 → C8 for track 2.
C1, C2 run continuously. C3, C4 fire per integration milestone.

---

## Q5. Planning: Gantt chart and milestones

The team's working Gantt is in `gantt/2026-05-08-rishi-gantt.png` (source
file: `drafts/2026-05-08-rishi-gantt.gantt`, importable into
[onlinegantt.com](https://www.onlinegantt.com/#/gantt)).

![Gantt chart, version 2026-05-08](gantt/2026-05-08-rishi-gantt.png)

Phase 1 (weeks 1-2, Apr 24 to May 8) produced the baseline plus
this report. Phase 2 (weeks 3-8, May 11 to Jun 12) splits into two
parallel tracks:

- **Track 1**: mandatory Zkne + LLVM unroll in week 3, then
  super-instruction across weeks 4-7.
- **Track 2**: SCA validation framework week 3, validation against
  unprotected baseline week 4, DOM-protected RTL weeks 4-6,
  protected compiler support weeks 5-7, final SCA validation
  week 7.

Milestones (dates from Rishi's chart):

- **M1, 2026-05-08.** Intermediate report submitted. Phase 1 closed.
- **M2, 2026-05-14.** `aes32esi`, `aes32esmi`, and loop-unroll all
  working. Sim still produces correct ciphertext via inline-asm path.
- **M3, 2026-05-15.** Bitstream for the mandatory variant generated;
  first cycle-count benchmark recorded.
- **M4, 2026-06-09.** Super-instruction (track 1) and DOM-protected
  variant (track 2) both have RTL and C files in.
- **M5, 2026-06-11.** Final validation. Track 1: full-encryption
  cycles within 25 % of projected ~12,000, board-verified. Track 2:
  TVLA passes at ∣t∣ < 4.5; key-rank confirms first-order resistance.
- **M6, 2026-06-12.** Source archive submitted, slides ready, demo
  rehearsed.
- **Weeks 25-26.** 60-min final slot: 20 pres + 10 demo + 20 Q&A.

Three risks worth calling out.

The LLVM rebuild for A4 takes 10-15 GB of disk in `$HOME` on the
shared server, and we don't yet know if it fits. If it doesn't,
A3's inline-asm path still gives us the cycle measurements; we just
miss having a clean intrinsic for the demo.

The OOC slack is +5.513 ns and a wide combinational SBox plus
partial-MixColumns network in the ALU will eat into it. If WNS
goes negative after the first synth pass, we pipeline the AES op
across two cycles. That costs one extra cycle per op but keeps
timing closed.

Track 2's framework is the biggest unknown because we're building
it without a ChipWhisperer. If the `.vcd`-based Hamming-distance
pipeline fails to discriminate on the unprotected baseline (the C7
sanity check), we revisit the model before relying on it for the
protected design.

---

## Source documents

All numbers above are reproducible from this repo:

- `BASELINE.md`: cycle, OOC area, OOC timing baseline
- `baselines/post-impl-2026-05-06/README.md`: post-impl area / timing / power baseline
- `PROFILING.md`: static + dynamic profiling, methodology, limits
- `references/kassimi-2026-secure-zkne-dom.pdf`: Kassimi/Taouil 2026 (track 2)
- `references/pan-2021-aes-coprocessor.pdf`: Pan 2021 (track 1 super-instruction)
- `drafts/2026-05-08-rishi-gantt.gantt`: team's working Gantt source file
- `gantt/2026-05-08-rishi-gantt.png`: exported Gantt image (drop the PNG here)
- `pdp-project-24/`: GitLab course repo with RTL + C, tracked as a submodule
