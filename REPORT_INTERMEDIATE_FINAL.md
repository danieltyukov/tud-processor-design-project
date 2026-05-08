# Intermediate Report: Final Answers

CESE4040 Processor Design Project, Q4 2025-2026, Group 24.
Submission window: 2026-05-04 to 2026-05-08 23:59 (one Brightspace
submission per group). Paste each section into the matching question.

Group 24 has 5 members: Daniel Tyukov, Rishi, Vishnu Karthik, Hruday
Gowda, Sathya. (Confirm Sathya's surname before submission.)

---

## Q1. What extension(s) and improvement(s) are you planning to implement?

We will implement two mandatory items plus one of two candidate
group-specific improvements. The pick depends on TA guidance and
Prof. Mottah Taouil's reply to our outreach about validation
methodology.

**Mandatory 1.** The Zkne instructions `aes32esi` and `aes32esmi`
in the RISCY core, from RISC-V Scalar Cryptography v1.0.1 (2022).
Each does one byte of work: extract a byte, run the AES S-box,
rotate to position, XOR into a destination register. `aes32esmi`
also applies one MixColumns row, so it's used in the middle
rounds. `aes32esi` skips MixColumns and is used in the final
round. We add them inside the CV32E40P ALU and decoder. We aim
for single-cycle execution where the timing slack allows it.

**Mandatory 2.** A built-in LLVM loop-unroll pass on the AES
middle-round loop. Once Mandatory 1 is in place, each output word
becomes a four-instruction `aes32esmi` chain. Unrolling the
surrounding loop removes loop overhead and lets the scheduler
interleave the chains. We use the existing `LoopUnrollPass` via
`-mllvm -unroll-count`, a `#pragma unroll`, or a small custom
pass, whichever is easiest in the LLVM build on the server.

**Option 1: side-channel-resilient variant using Domain-Oriented
Masking.** This follows Kassimi, Aljuffri, Larmann, Hamdioui,
Taouil (2026), "Secure Implementation of RISC-V's Scalar
Cryptography Extension Set". The paper is from our department and
Vishnu has contacted the senior author for guidance. The protected
variant masks the AES datapath so intermediate values don't reveal
key-dependent switching. That defends against first-order power
side-channel attacks. Validation uses TVLA, CPA, and key-rank
analysis on simulated power traces from `.vcd` waveforms via a
Hamming-distance leakage model.

**Option 2: custom super-instruction that fuses one AES
middle-round column into a single op.** The Zkne instructions only
do one byte at a time. One full output word still takes four
chained `aes32esmi` calls (16 per middle round, 144 per
encryption). We add one custom RV32 instruction under `custom-0`
that takes the four state-word source registers and produces one
output word in one cycle (or one pipelined burst). This collapses
144 instructions to 36. Inspired by Pan et al. (2021), "A
Lightweight AES Coprocessor Based on RISC-V Custom Instructions",
but instruction-level only: no DMA, no CBC orchestration in
hardware.

We propose two and pick one rather than committing to both because
each option needs its own validation pipeline that takes weeks to
set up. Doing both inside six weeks means doing both at half
quality.

---

## Q2. What metrics will be used to evaluate the final design?

Primary metric: cycle count for AES-128 ECB encryption of one
16-byte block, measured by `mem_snoop_match.CLK_COUNT` in
behavioural simulation from fetch-enable to the `0xDEADBEEF` end
sentinel. Baseline 59,560 cycles. Cycles are clean across RTL
changes; the FPGA and sim clocks are decoupled.

Common metrics, regardless of option:

- Functional correctness: ciphertext equals `fba50914 714bf41f 2e25aabe aaf9080f`.
- `mix_columns` cycle share, from `mcycle` CSR brackets. Baseline 83.8 %, target after the mandatory items: under 10 %.
- Area in LUTs and registers, OOC and post-impl. Baseline 5,691 / 2,524 OOC, 10,171 / 8,522 post-impl.
- Worst Negative Slack, OOC and post-impl. Baseline +5.513 ns OOC at 100 MHz, +28.306 ns post-impl at 20 MHz.
- Total on-chip power from `report_power`. Baseline 1.419 W (95 % is the always-on PS7).

If we pick Option 1, we also report:

- TVLA t-values on simulated power traces. Threshold ∣t∣ < 4.5 (Kassimi et al.). Unprotected fails by a wide margin; protected should pass.
- CPA correlation peaks per round-key byte. Unprotected: clear peaks after a few thousand traces. Protected: no clear peaks within our trace budget.
- Key-rank: trace count needed to push the correct key's rank below threshold. Higher is better.
- Power with switching activity from a `.saif` file (not vectorless), since masking shifts power slightly per Kassimi et al.

If we pick Option 2, the cycle metric does the heavy lifting.
Realistic projection from our profiling: about 5x reduction (around
12,000 cycles end-to-end). Target set at 2x (about 30,000 cycles)
for honest headroom.

All metrics reported as absolute value plus delta against the
unmodified baseline.

---

## Q3. Why have you chosen for these extension(s) / improvement(s)?

The mandatory items are required by the course, but they are also
the right starting point on the merits. Dynamic profiling shows
`mix_columns` is 83.8 % of cycles, with the inner software loop
already inlined by the compiler. Replacing those loops with
`aes32esmi` collapses the per-byte software cost by an order of
magnitude. Unrolling on top removes the residual loop overhead and
lets the scheduler interleave the four-`aes32esmi` chains.

Option 1 (side-channel) is justified because AES hardware without
side-channel protection is broken in any setting where the attacker
can measure power or EM emissions: IoT nodes, smart cards, secure
elements. Kassimi et al. report only +0.39 % area and 0 % runtime
overhead with proper scheduling, so a well-engineered final design
should have it. The team has good access here, since the paper is
from our department. The honest limitation is validation: the paper
used a ChipWhisperer rig and we don't have one, so our TVLA and CPA
run on simulated traces extracted from `.vcd` waveforms via a
Hamming-distance leakage model. That's a simulation-based
assessment, not real-silicon measurement, and we'd report it as
such. There's also a small core mismatch (Kassimi used CV32E40S; we
have CV32E40P), so non-trivial integration work on top of porting
the masking logic.

Option 2 (super-instruction) is justified because AES is a real
workload (TLS, secure boot, sensor authentication all run this
exact path) and even with Zkne in place, one output word still
costs four chained `aes32esmi` calls. Folding each chain into one
instruction reduces the dynamic instruction count 4x and removes
register-file traffic between the four steps. Pan et al. reported
25-38 % runtime gain with a similar strategy on a smaller in-order
core; our version is narrower (no DMA, no CBC handling), so we
expect a smaller gain than they did, but still material on top of
`aes32esmi` alone.

We propose two and commit to one because each option's validation
framework takes weeks to set up. Option 1 needs the TVLA/CPA
simulation pipeline; Option 2 needs the cycle-comparison and
post-impl-area sweep. Two parallel frameworks in six weeks means
running both at half quality. The TA's view on which option fits
the course's intent, plus Prof. Mottah's view on whether our
simulated Option-1 validation is rigorous enough, will decide the
pick.

---

## Q4. Methodology: tasks, ownership, integration / baseline / validation

We split the five of us into three sub-teams (agreed 2026-05-08).
Split is provisional and will rebalance once we commit to an option.

- **RTL team (2 people).** Zkne instruction RTL, OOC and post-impl synthesis loop. Carries the bulk of the work for Option 2; contributes alongside the validation team for Option 1.
- **Validation team (2 people).** Benchmark suite and the cross-iteration sim+correctness loop. Carries the bulk of the work for Option 1 (validation framework + DOM-protected RTL); lighter weeks otherwise.
- **Compiler team (1 person).** LLVM intrinsics and loop-unroll pass for the mandatory items. Adds compiler support for whichever option is chosen.

**A) Integration**

| ID | Task | Team | Effort |
|---|---|---|---:|
| A1 | `aes32esi` decode + execute in `cv32e40p_decoder.sv`, `cv32e40p_alu.sv`, `cv32e40p_pkg.sv` | RTL | ~15 h |
| A2 | `aes32esmi` decode + execute, same files | RTL | ~20 h |
| A3 | Verify GAS encoding; expose to C via `asm volatile` (no LLVM rebuild) | Compiler | ~6 h |
| A4 | `__builtin_riscv_aes32esi`/`aes32esmi` intrinsics in LLVM RISC-V backend; rebuild LLVM in `$HOME` | Compiler | ~20 h |
| A5 | Wire LLVM `LoopUnrollPass` to fully unroll the middle-round loop | Compiler | ~8 h |
| A6 | [Opt 2] Super-instruction RTL (custom-0 opcode, fused middle-round word) | RTL | ~25 h |
| A7 | [Opt 2] Super-instruction compiler support: LLVM intrinsic + C glue | Compiler | ~10 h |
| A8 | [Opt 1] SCA validation framework: `.vcd` extract, Hamming-distance traces, TVLA/CPA/key-rank scripts | Validation | ~25 h |
| A9 | [Opt 1] DOM-protected `aes32esi`/`aes32esmi`: masked SBox, masked partial MixColumns, build switch | Validation | ~30 h |
| A10 | [Opt 1] Compiler support for protected variant: scheduling-aware emission | Compiler | ~10 h |

A1-A5 always run. We execute the [Opt 1] tasks if we commit to the
side-channel variant, or the [Opt 2] tasks if we commit to the
super-instruction.

**B) Baseline (mostly done in Phase 1)**

| ID | Task | Status |
|---|---|---|
| B1 | Cycle baseline via `mem_snoop_match.CLK_COUNT` | done. 59,560 cycles, ciphertext PASSED, see `BASELINE.md` |
| B2 | OOC synthesis baseline | done. 5,691 LUTs / 2,524 regs / 5 DSPs / WNS +5.513 ns |
| B3 | Post-impl baseline (full `riscv_wrapper`, routed) | done 2026-05-06. 10,171 LUTs / 8,522 regs / 16 BRAMs / 5 DSPs / +28.306 ns @ 20 MHz / 1.419 W. See `baselines/post-impl-2026-05-06/` |
| B4 | Static profiling from `objdump -d` | done. `PROFILING.md` § 1-6, `mix_columns` ~88 % static |
| B5 | Dynamic profiling via `mcycle` brackets | done 2026-05-02. `mix_columns` 83.8 % measured, cross-validates static |

**C) Validation and measurements**

| ID | Task | Team | When |
|---|---|---|---|
| C1 | Re-run baseline AES sim after every RTL change. Confirm `Test PASSED`, record cycles, diff against 59,560 | Validation | continuous |
| C2 | Re-run OOC synth, capture LUT/reg/DSP delta and WNS impact | RTL | continuous |
| C3 | Generate full bitstream after each clean sim+synth pair (`gen_bitstream.tcl`). Pipeline already proven (4,045,673 B `riscv_wrapper.bit` built 2026-05-08) | RTL | per iteration |
| C4 | Upload to PYNQ-Z1, run `base_riscy.ipynb`, confirm wall-clock ciphertext matches sim | RTL | per iteration |
| C5 | Re-run dynamic profiling after `aes32esmi` lands; confirm `mix_columns` drops below 10 % | Validation | once after Mandatory 1 |
| C6 | Final benchmark: cycles + ciphertext on multiple AES test vectors (not just shipped one) | Validation | end of Phase 2 |
| C7 | [Opt 1] TVLA on simulated traces from unprotected baseline. Should fail (must show leakage) to prove the framework works | Validation | week 5 |
| C8 | [Opt 1] TVLA + CPA + key-rank on simulated traces from protected variant. Should pass at ∣t∣ < 4.5 | Validation | week 7 |
| C9 | Final write-up, slides, demo, archive | All 5 | last week |

Order: B (mostly done) then A1, A2 (parallel) then A3 then A4, A5
(parallel), then either A6 + A7 (Option 2) or A8 + A9 + A10 + C7 +
C8 (Option 1). C1, C2 run continuously. C3, C4 fire per integration
milestone.

---

## Q5. Planning: Gantt chart and milestones

The team's working Gantt is `gantt/2026-05-08-rishi-gantt.png`
(source file: `drafts/2026-05-08-rishi-gantt.gantt`, importable
into [onlinegantt.com](https://www.onlinegantt.com/#/gantt)).

![Gantt chart, version 2026-05-08](gantt/2026-05-08-rishi-gantt.png)

Phase 1 (weeks 1-2, Apr 24 to May 8) produced the baseline plus
this report. Phase 2 (weeks 3-8, May 11 to Jun 12) starts with the
mandatory items, then runs whichever option we commit to. The chart
shows both candidate paths so we can plan either; once we commit,
the unused track's tasks drop and its people pick up other work.

Milestones (dates from Rishi's chart):

- **M1, 2026-05-08.** Intermediate report submitted. Phase 1 closed.
- **M2, 2026-05-14.** `aes32esi`, `aes32esmi`, and loop-unroll all working. Sim still produces the correct ciphertext via the inline-asm path.
- **M3, 2026-05-15.** Bitstream for the mandatory variant generated; first cycle-count benchmark recorded against 59,560.
- **M3.5, ~2026-05-15.** Decision on group-specific option. TA feedback received and Prof. Mottah's reply in hand. Team commits to Option 1 or Option 2.
- **M4, 2026-06-09.** Whichever option we picked has RTL and C files in. Option 2: super-instruction functional. Option 1: DOM-protected variant functional.
- **M5, 2026-06-11.** Final validation. Option 2: full-encryption cycles within 25 % of projected ~12,000, board-verified. Option 1: TVLA passes at ∣t∣ < 4.5 and key-rank confirms first-order resistance under our simulated power model.
- **M6, 2026-06-12.** Source archive submitted, slides ready, demo rehearsed.
- **Weeks 25-26.** 60-min final slot: 20 pres + 10 demo + 20 Q&A.

Risks:

1. The LLVM rebuild for A4 takes 10-15 GB of disk in `$HOME` on the shared server, and we don't yet know if it fits. Fallback: A3's inline-asm path still gives us the cycle measurements, just without a clean intrinsic for the demo.
2. OOC slack is +5.513 ns and a wide combinational SBox plus partial-MixColumns network in the ALU will eat into it. If WNS goes negative, we pipeline the AES op across two cycles. Costs one extra cycle per op, keeps timing closed.
3. If we commit to Option 1, the validation framework is the biggest unknown because we're building it without a ChipWhisperer. If the `.vcd`-based Hamming-distance pipeline fails to discriminate on the unprotected baseline (the C7 sanity check), we revisit the model before relying on it for the protected design. This is why we asked Prof. Mottah for guidance before committing: if the simulated approach won't produce a defensible claim, Option 2 is the safer pick.

---

## Source documents

All numbers above are reproducible from this repo:

- `BASELINE.md`: cycle, OOC area, OOC timing baseline
- `baselines/post-impl-2026-05-06/README.md`: post-impl area / timing / power
- `PROFILING.md`: static + dynamic profiling, methodology, limits
- `references/kassimi-2026-secure-zkne-dom.pdf`: Kassimi/Taouil 2026 (Option 1)
- `references/pan-2021-aes-coprocessor.pdf`: Pan 2021 (Option 2)
- `drafts/2026-05-08-rishi-gantt.gantt`: team's working Gantt source
- `gantt/2026-05-08-rishi-gantt.png`: exported Gantt image
- `pdp-project-24/`: GitLab course repo (RTL + C), tracked as a submodule
