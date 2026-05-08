# Intermediate Report — Final Answers

CESE4040 Processor Design Project, Q4 2025-2026 — Group 24
Submission window: 2026-05-04 → 2026-05-08 23:59 (one Brightspace
submission per group). Paste each section verbatim into the
corresponding question.

Group 24 has 5 members: Daniel Tyukov (datyukov), Rishi, Vishnu
Karthik, Hruday Gowda, Sathya. (Confirm Sathya's surname / NetID
before submission.)

---

## Q1. What extension(s) and improvement(s) are you planning to implement?

We plan to implement three things in total. The first two are the
mandatory Zkne and LLVM deliverables; the third is our group-specific
improvement.

1. **The Zkne instructions `aes32esi` and `aes32esmi` in the RISCY
   core.** These come from the RISC-V Scalar Cryptography Extension
   (Zkne, ratified 1.0.1, 2022). Each instruction does one byte's
   worth of work: extract a byte, apply the AES S-box, rotate it to
   the right position, XOR it into a destination register. `aes32esmi`
   also applies one row of the MixColumns matrix and is used for the
   middle rounds; `aes32esi` skips the MixColumns step and is used for
   the final round. We plan to add them inside the existing CV32E40P
   ALU, decoder, and packed type definitions. Optimisation target:
   latency. We want them to execute in a single cycle wherever the
   timing slack allows.

2. **A built-in LLVM loop-unroll pass on the AES middle-round loop.**
   The loop currently runs nine middle rounds, each computing four
   output words. After (1) is in place, each output word becomes a
   four-instruction chain of `aes32esmi`. Unrolling this loop lets the
   instruction scheduler interleave the chains, removes the loop
   overhead, and exposes more independent work. We plan to apply
   LLVM's existing `LoopUnrollPass` either through the
   `-mllvm -unroll-count` flag, an explicit `#pragma unroll`
   in the C source, or a small custom pass that recognises the loop
   by metadata. Whichever of those proves easiest in the LLVM build
   we have on the server is what we'll use.

3. **A custom "super-instruction" that fuses one AES middle-round
   column into a single op.** The Zkne instructions only do one byte
   of work at a time. Computing one full output word of one round
   takes four chained `aes32esmi` calls, so a full middle round needs
   sixteen of them, and a full encryption needs 144. We plan to add
   one custom RV32 instruction (under the `custom-0` opcode space)
   that takes the four state-word source registers as input and
   produces one output word directly, in one cycle or one fixed
   pipelined burst. This collapses the 144 instructions to 36.
   The idea is inspired by Pan et al. (2021), "A Lightweight AES
   Coprocessor Based on RISC-V Custom Instructions", but we are
   keeping it instruction-level: no DMA, no CBC orchestration in
   hardware, just the inner middle-round kernel. Their full design
   is too large to fit our 8-week budget; the kernel idea fits.

We considered a fourth option, which is making the AES instructions
resilient to power side-channel attacks via Domain-Oriented Masking,
following Kassimi, Aljuffri, Larmann, Hamdioui, and Taouil (2026),
"Secure Implementation of RISC-V's Scalar Cryptography Extension
Set". The paper is from this department and Prof. Mottah Taouil is
the senior author. We have decided not to commit to it as part of
the plan because the paper validates with a ChipWhisperer hardware
setup and we do not have one. The fallback is to extract power
traces from `.vcd` waveform files via a Hamming-distance leakage
model and run TVLA / CPA in software, which is a sizeable project on
its own. The paper also evaluates on the CV32E40S core, which has a
slightly different pipeline configuration than our CV32E40P, so the
port is not free either. If the three improvements above land ahead
of schedule we will pursue this as a stretch goal, otherwise we
prefer to deliver one improvement well rather than two halfway.

---

## Q2. What metrics will be used to evaluate the final design?

Our primary metric is **cycle count for AES-128 ECB encryption of one
16-byte block**, measured in behavioural simulation by the
`mem_snoop_match.CLK_COUNT` counter in `zynq_tb.sv` from the
fetch-enable rising edge to the `0xDEADBEEF` end sentinel. The
unmodified baseline is 59,560 cycles. We use cycles, not wall-clock
time, because the FPGA clock and the simulation clock are decoupled,
and cycles are the cleanest comparison across RTL changes.

Alongside the cycle count we will report:

- **Functional correctness** — every run must produce the ciphertext
  `fba50914 714bf41f 2e25aabe aaf9080f`. We check this in the same
  testbench and fail the run if it differs. This is verification, not
  scoring, but it is the precondition for any cycle count being
  meaningful.

- **The mix_columns share of cycles**, captured by reading the
  `mcycle` CSR around each AES phase and writing the deltas to BRAM
  for the testbench to read out. The baseline value is 83.8 % of
  cycles in `mix_columns`. After (1) and (2) land we expect this to
  drop below 10 %; after (3) lands we expect a further reduction. The
  share is what tells us whether we are still attacking the hot path
  or whether some other phase has become dominant.

- **Area, in LUTs and registers, for the full RISCY core.** We report
  this both core-only (Out-of-Context synthesis) and full design
  (post-implementation, routed). Baseline: 5,691 LUTs / 2,524 regs in
  OOC; 10,171 LUTs / 8,522 regs / 16 BRAMs / 5 DSPs after full impl.
  We track this per RTL change to catch the case where the
  super-instruction's combinational SBox + MixColumns network grows
  the ALU more than the cycle savings justify.

- **Worst Negative Slack (WNS)** in OOC and post-impl. Baseline: +5.513 ns
  in OOC at the 100 MHz constraint, and +28.306 ns post-impl at the
  20 MHz constraint. Adding a wide combinational AES op to the ALU
  will eat into this; we want to know how much.

- **Total on-chip power** from `report_power` after implementation.
  Baseline: 1.419 W, of which 1.256 W (95 %) is the always-on PS7.
  We track this for completeness but do not expect the small Zkne /
  super-instruction additions to move it visibly given the PS7's
  share. If the team revisits side-channel resistance as a stretch
  goal, this is where the analysis would live, with switching
  activity supplied from a `.saif` file rather than the vectorless
  default.

We will report each metric as an absolute value plus a delta against
the unmodified baseline. The realistic projection from our profiling
is roughly 5x cycle reduction (about 12,000 cycles) once all three
improvements are in. We are setting the *target* at 2x (about 30,000
cycles) so we have honest headroom for implementation drift.

---

## Q3. Why have you chosen for these extension(s) / improvement(s)?

The mandatory Zkne instructions and the loop-unroll pass are required
by the course brief, but they are also the right starting point on
the merits. The dynamic profiling we ran on the unmodified system
showed `mix_columns` accounts for 83.8 % of all cycles, with a
software inner loop of inlined `gf_mult` calls that the compiler had
already fully expanded. Replacing those loops with `aes32esmi`
collapses the per-byte software cost by roughly an order of
magnitude. Loop-unrolling the surrounding middle-round loop on top
removes the remaining loop overhead and lets the scheduler
interleave the four-`aes32esmi` chains for each column. Both changes
attack the hot path directly.

We chose the super-instruction as our group-specific improvement
for three reasons. First, AES is a real workload. Embedded systems
that do TLS termination, secure boot, or sensor authentication run
this exact code path, and lower per-block cost shows up as either
lower latency on the critical path or lower energy per packet,
depending on what the system is bound by. Second, the Zkne
instructions only finish part of the job. Even after they are in
place, computing one output word of one round still takes four
chained `aes32esmi` calls (16 per middle round, 144 per
encryption). Folding each four-instruction chain into one
instruction reduces the dynamic instruction count 4x at the cycle
level, and probably more at the energy level because we eliminate
register-file accesses between the four steps. Third, Pan et al.
reported a 25-38 % runtime gain with a similar custom-instruction
strategy on a smaller in-order RISC-V core. Our adapted version is
narrower than theirs (no DMA, no CBC handling in hardware, just the
middle-round kernel), so we expect a smaller absolute gain than
they did, but we still expect it to be material on top of `aes32esmi`
alone.

The reason for not committing to the side-channel-resilient design
is mostly practical. The Kassimi paper relies on a ChipWhisperer
power-measurement rig for its empirical TVLA / CPA validation, and
without one our validation has to fall back to power-trace estimation
from `.vcd` files using a Hamming-distance model. That estimation is
not the experiment the paper actually ran, and we would be claiming
side-channel resistance on the basis of a different measurement.
Second, the paper integrates DOM into the CV32E40S core; we have the
CV32E40P. The Zkne instruction semantics are the same, but the
pipelines differ enough that the integration is non-trivial work.
Running two independent tracks (super-instruction and DOM) in
parallel risks delivering both at half quality. We would rather do
one of them properly.

---

## Q4. Methodology — tasks, ownership, integration / baseline / validation

Our work breakdown groups into three blocks as the rubric asks:
integration, baseline definition, and validation/measurements. Phase
1 baseline work is mostly done. Phase 2 starts after this report
goes in. We are five people; assignments below are based on the
team's 2026-05-07 discussion. The split is not set in stone and we
expect to rebalance as people hit or unblock specific subtasks.

**A) Integration**

| ID | Task | Owner(s) | Effort |
|---|---|---|---:|
| A1 | Decode + execute `aes32esi` (final-round) in `cv32e40p_decoder.sv`, `cv32e40p_alu.sv`, `cv32e40p_pkg.sv` | Hruday, Sathya, Vishnu | ~15 h |
| A2 | Decode + execute `aes32esmi` (middle-round) in the same files | Vishnu, Rishi, Daniel | ~20 h |
| A3 | Verify GAS encoding of the new instructions and expose them to C through `asm volatile` so we can use them without a full LLVM rebuild | Hruday | ~6 h |
| A4 | Add `__builtin_riscv_aes32esi` and `aes32esmi` intrinsics in the LLVM RISC-V backend; rebuild LLVM into `$HOME` on the server (the `/data/mirror/llvm/build-release` tree is read-only) | Hruday | ~20 h |
| A5 | Wire LLVM's `LoopUnrollPass` to fully unroll the AES middle-round loop, either via `-mllvm -unroll-count`, an `#pragma unroll`, or a small custom pass | Hruday | ~8 h |
| A6 | Implement the super-instruction: RTL decoder + ALU op (custom-0 opcode), plus an LLVM intrinsic, plus the C glue that uses it. RTL pair-programmed by Vishnu and Rishi, LLVM by Hruday, C glue by Daniel, sim harness by Sathya. | All 5 | ~30 h shared |

**B) Definition of baseline (for comparison)**

| ID | Task | Owner(s) | Status |
|---|---|---|---|
| B1 | Cycle-count baseline from behavioural simulation (`mem_snoop_match.CLK_COUNT`) | Daniel, Rishi | done — 59,560 cycles, ciphertext PASSED, see `BASELINE.md` |
| B2 | Out-of-Context synthesis baseline: LUTs / regs / DSPs / WNS for the core only | Daniel, Rishi | done — 5,691 LUTs / 2,524 regs / 5 DSPs / WNS +5.513 ns |
| B3 | Post-implementation baseline for the full `riscv_wrapper`: routed area, timing, power | Rishi | done 2026-05-06 — 10,171 LUTs / 8,522 regs / 16 BRAMs / 5 DSPs / WNS +28.306 ns @ 20 MHz / 1.419 W on-chip; details in `baselines/post-impl-2026-05-06/` |
| B4 | Static profiling: instruction counts per AES function from `riscv32-unknown-elf-objdump -d` | Daniel | done — `PROFILING.md` § 1-6, `mix_columns` ~88 % static |
| B5 | Dynamic profiling: `mcycle` CSR brackets around each AES phase, results dumped to BRAM | Daniel | done 2026-05-02 — `mix_columns` measured at 83.8 % of cycles, cross-validates the static estimate |

**C) Validation and measurements**

| ID | Task | Owner(s) | When |
|---|---|---|---|
| C1 | After every RTL change, re-run baseline AES simulation, confirm `Test PASSED`, record the cycle count, and diff against 59,560. | Sathya, Hruday | continuous |
| C2 | After every RTL change, re-run OOC synthesis and capture the LUT / register / DSP delta and the WNS impact. | Rishi | continuous |
| C3 | Generate the full bitstream after each clean sim+synth pair using `gen_bitstream.tcl`. The pipeline is verified: we already produced one (4,045,673 B, identical to the course-shipped baseline) on 2026-05-08. | Rishi | per iteration |
| C4 | Upload the bitstream to the PYNQ-Z1 via Jupyter, run `base_riscy.ipynb`, confirm the wall-clock AES output matches the simulation ciphertext. | Rishi, Daniel | per iteration |
| C5 | After `aes32esmi` lands, re-run the dynamic profiling and confirm `mix_columns` drops below 10 % of cycles as predicted. | Daniel | once per integration milestone |
| C6 | Final benchmark suite: run the cycle-count + ciphertext check on multiple AES test vectors (not just the single shipped one) so the result is not vector-specific. | Sathya | end of Phase 2 |
| C7 | Final write-up, slides, demo script, and submission archive (RTL diffs + LLVM mods + scripts). | All 5 | last week of Phase 2 |

The order is roughly B → A1, A2 → A3 → A4, A5 → A6, with C1, C2 running
continuously throughout, C5 firing once after A2 is in, and C3, C4
firing per integration milestone. The dependencies are documented in
the Gantt chart below.

---

## Q5. Planning — Gantt chart and milestones

Phase 1 covers weeks 1-2 (April 24 to May 8) and produced the
baseline plus this report. Phase 2 covers weeks 3-8 (May 9 to
June 12) and contains all the implementation and validation work.

```
Week-of (Fri to Thu)      |W1 Apr24-30|W2 May01-07|W3 May08-14|W4 May15-21|W5 May22-28|W6 May29-Jun04|W7 Jun05-11|W8 Jun12  |
=======================================================================================================================
PHASE 1 - bring-up + plan
B1 sim baseline           |###########|           |           |           |           |              |           |          |
B2 OOC baseline           |###########|           |           |           |           |              |           |          |
B4 static profiling       |###########|           |           |           |           |              |           |          |
B5 dynamic profiling      |           |###########|           |           |           |              |           |          |
B3 post-impl baseline     |           |#####      |           |           |           |              |           |          |
Q1-Q5 intermediate report |           |     ######|###        |           |           |              |           |          |
                          |           |           | M1 5/8    |           |           |              |           |          |
PHASE 2 - implement + evaluate
A1 aes32esi RTL           |           |           |   ########|###########|##         |              |           |          |
A2 aes32esmi RTL          |           |           |   ########|###########|##         |              |           |          |
C1/C2 cont. sim+synth     |           |           |   ########|###########|###########|##############|###########|          |
A3 GAS asm exposure       |           |           |           |           | ######    |              |           |          |
A4 LLVM intrinsic         |           |           |           |           |     ######|##########    |           |          |
A5 LLVM loop unroll       |           |           |           |           |     ######|######        |           |          |
A6 super-instruction      |           |           |           |           |        ###|##############|######     |          |
C3 bitstream gen          |           |           |           |           |   .       |   .          |   .       |          |
C4 PYNQ verification      |           |           |           |           |       .   |       .      |       .   |          |
C5 dynamic re-profile     |           |           |           |           |       ####|              |           |          |
C6 benchmark suite        |           |           |           |           |           |              |#####      |          |
C7 report + slides + demo |           |           |           |           |           |              |  ######## |######    |
                          |           |           |           |           |           |              |           | M5 6/12  |
```

Milestones we track against:

- **M1, 2026-05-08 (Friday, end of week 2)** — Intermediate report
  submitted on Brightspace. Phase 1 closed: simulation, OOC and
  post-impl baselines all measured and documented; profiling shows
  `mix_columns` is 83.8 % of cycles; bitstream pipeline proven
  end-to-end.

- **M2, 2026-05-23 (Saturday, end of week 4)** — `aes32esi` and
  `aes32esmi` decoded and executed in RTL. AES sim still produces
  the correct ciphertext using the inline-asm path. Cycle count
  recorded.

- **M3, 2026-06-02 (Tuesday, mid week 6)** — LLVM toolchain emits
  both new instructions through intrinsics. Loop-unroll pass active
  on the middle-round loop. End-to-end AES cycle count within 25 %
  of the projected ~17,000.

- **M4, 2026-06-09 (Tuesday, mid week 7)** — Super-instruction
  implemented in RTL plus LLVM. Full encryption cycle count within
  25 % of the projected ~12,000. Bitstream verified on the PYNQ-Z1
  at the same wall-clock cycle count.

- **M5, 2026-06-12 (Friday, end of week 8)** — Final source archive
  submitted on Brightspace. Slides ready, demo script rehearsed.

- **M6, weeks 25-26** — 60-minute final slot per group: 20-minute
  presentation + 10-minute demo + 20-minute Q&A.

The dependency order is B (baselines, mostly done) -> A1, A2 (in
parallel) -> A3 (asm exposure) -> A4, A5 (LLVM, in parallel) -> A6
(super-instruction, the convergence point) -> C5, C6 (final
measurements) -> C7 (write-up). C1, C2, C3, C4 run continuously as
sanity checks against each integration milestone.

The two risks worth calling out are the LLVM rebuild and the WNS
budget. The LLVM rebuild for A4 is a one-time cost on the shared
server and we don't know yet whether `$HOME` has enough disk for it
(rough estimate 10-15 GB of build output); if it doesn't, A3's
inline-asm path still gives us the cycle measurements we need, just
without the toolchain integration for the final demo. The WNS
budget is +5.513 ns in OOC, and adding a wide combinational SBox +
partial-MixColumns network to the ALU will consume some of that;
if it goes negative after the first synthesis iteration, we will
pipeline the AES op across two cycles, which costs us one cycle per
op but keeps the design closing timing.

---

## Source documents

All numbers cited above are reproducible from this repo:

- `BASELINE.md` — measured cycle / OOC area / OOC timing baseline
- `baselines/post-impl-2026-05-06/README.md` — post-impl area / timing / power baseline (full design, routed)
- `PROFILING.md` — static + dynamic profiling, methodology, limits
- `references/kassimi-2026-secure-zkne-dom.pdf` — Kassimi/Taouil 2026 (deferred side-channel option)
- `references/pan-2021-aes-coprocessor.pdf` — Pan 2021 (super-instruction inspiration)
- `pdp-project-24/` — the GitLab course repo, RTL + C sources, tracked as a submodule
