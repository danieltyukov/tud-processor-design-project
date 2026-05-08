# Intermediate Report — Group 24

**CESE4040 Processor Design Project, Q4 2025-2026**
**Group 24** · TU Delft · Brightspace submission window: 2026-05-04 → 2026-05-08

> **How to use this file**: prose draft mapped to the actual five
> Brightspace quiz questions (Q1–Q5). When you fill the quiz, paste
> each section verbatim. Numbers cite `BASELINE.md`, `PROFILING.md`,
> and `baselines/post-impl-2026-05-06/README.md`.
>
> Working drafts from the team (e.g. `drafts/2026-05-08-hruday-quiz-draft.txt`)
> have been folded into the answers below. Cited papers are in `references/`.

---

## Team

Group 24 has **5 members**. Roles for the report (the actual Phase 2
work split is the same — see Q4):

- **Daniel Tyukov** (datyukov) — repo + GitHub mirror + helper scripts; report compilation; baseline measurement.
- **Rishi** — Vivado implementation flow; area / power / timing post-impl reports; baseline co-owner.
- **Vishnu Karthik** — state-of-the-art research; supervisor liaison (emailing Prof. Mottah Taouil); side-channel resilience track.
- **Hruday Gowda** — instruction-set research; "super-instruction" (Pan et al.) track lead; quiz writer.
- **Sathya** — validation / measurement track lead.

---

## Q1 — Extensions and improvements we plan to implement

We plan **all three** of the following. The first two are course-mandated; the third is our group-specific improvement.

### 1. Mandatory: RISC-V Zkne instructions in the RISCY core

Implement `aes32esi` and `aes32esmi` from the **RISC-V Scalar
Cryptography Extension v1.0.1 (Zkne)** [1] inside the CV32E40P
ALU and decoder. Each instruction performs one byte-lane of one AES
round (SBox + rotate + XOR; `aes32esmi` additionally applies one row
of the MixColumns matrix). Optimisation target: **latency** — no
extra pipeline stage, single-cycle execution where slack permits.

### 2. Mandatory: Built-in LLVM loop-unroll pass on the AES middle round

Apply LLVM's `LoopUnrollPass` to the AES middle-round loop
(currently 9 iterations × 4 columns) so each unrolled iteration
emits the four `aes32esmi` instructions for one column inline.
Done either via `-mllvm -unroll-count` flag, an `#pragma unroll`
hint, or a small custom pass that targets the loop by metadata.

### 3. Group-specific: AES "super-instruction" (custom fused middle-round op)

Introduce a single **custom RV32 instruction** that, in one cycle (or
one fixed multi-cycle pipeline burst), computes one **full output
word** of an AES middle round — the work currently done by **four
chained `aes32esmi`** calls. Inputs: four state-word source registers
(`a4..a7`); output: one destination word (`t0`). Encoded under the
RISC-V `custom-0` opcode space. Full middle round = 4 invocations
instead of 16, full encryption = 36 invocations instead of 144.

This is inspired by **Pan et al. (2021)** — *A Lightweight AES Coprocessor
Based on RISC-V Custom Instructions* [2] — but radically simplified:
we keep the instruction-level (no DMA, no CBC orchestration in
hardware) and target only the inner middle-round kernel.

> **Side-channel-resilient AES variant** (DOM-protected, after
> Kassimi, Aljuffri, Larmann, Hamdioui, Taouil 2026 [3]) was a
> serious second candidate. Per the team's 2026-05-07 discussion and
> Vishnu's outreach to Prof. Taouil, we are *parking* this option:
> the validation pipeline (TVLA / CPA on `.vcd`-derived Hamming-
> distance traces, since we don't have a ChipWhisperer) is a project
> in itself, and we'd rather deliver one improvement well than two
> partially. If time allows after the mandatory deliverables and the
> super-instruction land, we will revisit this as a stretch goal.

---

## Q2 — Metrics used to evaluate the final design

**Primary metric: cycle reduction on AES-128 ECB encryption of one
16-byte block,** measured by `mem_snoop_match.CLK_COUNT` between
fetch-enable rising edge and the `0xDEADBEEF` end sentinel. Baseline
= **59,560 cycles** (`BASELINE.md` § 1).

**Secondary metrics, all measured against the same baseline:**

| # | Metric | How we measure | Baseline |
|---|---|---|---|
| 1 | Total simulated cycles | Vivado XSim, `mem_snoop_match.CLK_COUNT` | 59,560 |
| 2 | `mix_columns` cycle share | `mcycle` CSR brackets per AES phase | 83.8 % (50,643 cycles) |
| 3 | Static instruction count | `riscv32-unknown-elf-objdump -d` on `soft.elf` | ~30k after compiler-fix; mix_columns ~88 % |
| 4 | OOC LUT count | `report_utilization` on core-only | 5,691 LUTs |
| 5 | OOC WNS / Fmax | `report_timing_summary` on core-only @100 MHz constraint | +5.513 ns; 222 MHz theoretical |
| 6 | Post-impl LUT count | `report_utilization` on full `riscv_wrapper` routed | 10,171 LUTs |
| 7 | Post-impl WNS | full design @ 20 MHz constraint | +28.306 ns (Fmax ≈ 46 MHz) |
| 8 | Post-impl on-chip power | `report_power` (vectorless) | 1.419 W total (~0.027 W in the PL fabric, rest is PS7) |
| 9 | Functional correctness | Ciphertext equality with `fba50914 714bf41f 2e25aabe aaf9080f` | PASSED |

**Targets** (versus the 59,560-cycle baseline):

| Scenario | Projected cycles | Speedup |
|---|---:|---:|
| Mandatory deliverables only, half-effective `aes32esmi` | ~30,000 | ~2× |
| Mandatory deliverables fully effective + loop unroll | ~17,000 | ~3.5× |
| Mandatory + super-instruction (Q1 #3) | ~10,000–12,000 | ~5× |

---

## Q3 — Why these extensions / improvements

### Why latency (cycle count) as the primary metric

1. The course-mandated instructions and the loop-unroll pass directly
   target instructions executed per AES round. Their effect is
   naturally measured as a cycle delta.
2. The baseline is reproducible (`make soft` → byte-identical
   `.coe`) and has a robust end-of-test sentinel. Cycle deltas are
   apples-to-apples comparable across changes.
3. Dynamic profiling shows `mix_columns` accounts for **83.8 % of all
   cycles** in the baseline (`PROFILING.md` § 7). Both the Zkne
   instructions and the super-instruction attack exactly that hot-path,
   so a measurable win is highly likely.

### Why the super-instruction (Q1 #3)

1. **AES is everywhere — encryption-in-line for embedded comms is a
   normal product requirement** (TLS, secure boot, IoT). Lower
   per-block cost translates directly into either lower latency or
   lower energy per packet.
2. **The Zkne instructions only "half-finish" the work.** Computing
   one full output word of one AES round still takes four chained
   `aes32esmi` instructions (= 16 per middle round = 144 per
   encryption). A fused instruction reduces this 4×.
3. **Pan et al. 2021 [2] reported 25.3–37.9 % runtime gain** with a
   similar custom-instruction strategy on a smaller in-order RISC-V
   core (Hummingbird E203). Even a degraded version of that — applied
   only to the middle round, no DMA or CBC orchestration — should
   materially exceed the speedup of `aes32esmi` alone.
4. **It is implementable in our 8-week budget.** Reusing the SBox +
   partial-MixColumns combinational logic we already need for
   `aes32esmi`, plus a 32-bit-wide write-back path, fits inside the
   +5.513 ns OOC slack of `BASELINE.md` § 2.2.

### Why we deferred side-channel resistance (DOM, Kassimi 2026 [3])

It is a strong candidate from a TU Delft paper authored by Prof.
Mottah Taouil himself, with reported overhead of only +0.39 % area /
0 % perf. We deferred it because:

- Validation requires power traces. The paper used a ChipWhisperer
  hardware setup; we don't have one. The fallback (Hamming-distance
  estimation from `.vcd` files + TVLA / CPA in software) is a
  significant project on its own.
- They evaluated on **CV32E40S**, not our **CV32E40P**. The core has
  different pipeline depth and ISA configuration; non-trivial port.
- Two tracks (super-instruction + DOM) in 6 weeks risks delivering
  neither well.

We will pursue this as a stretch goal if Phase 2 finishes the
super-instruction track ahead of schedule.

---

## Q4 — Methodology: tasks, ownership, A/B/C breakdown

### A) Integration tasks (RTL + compiler + simulation/build pipeline)

| ID | Subtask | Owner(s) | Effort | Target completion |
|---|---|---|---:|---|
| **A1** | Implement `aes32esi` decode + execute (final-round encrypt) in `cv32e40p_decoder.sv`, `cv32e40p_alu.sv`, `cv32e40p_pkg.sv` | **Hruday + Sathya + Vishnu** | ~15 h | 2026-05-23 |
| **A2** | Implement `aes32esmi` decode + execute (middle-round encrypt) | **Vishnu + Rishi + Daniel** | ~20 h | 2026-05-23 |
| **A3** | Verify GAS encoding of new instructions; expose to C via `asm volatile` so the AES source can emit them | **Hruday** | ~6 h | 2026-05-26 |
| **A4** | Add `__builtin_riscv_aes32esi` / `aes32esmi` intrinsics in the LLVM RISC-V backend; rebuild LLVM in `$HOME` on the server | **Hruday** | ~20 h | 2026-06-02 |
| **A5** | Configure the existing `LoopUnrollPass` to fully unroll the AES middle-round loop (`-mllvm -unroll-count` flag or custom pass) | **Hruday** | ~8 h | 2026-06-02 |
| **A6** | Implement the **custom super-instruction** (one fused middle-round word op, `custom-0` opcode space): RTL decoder + ALU op + LLVM intrinsic | **All 5 (split: RTL=Vishnu+Rishi, LLVM=Hruday, C glue=Daniel, sim harness=Sathya)** | ~30 h shared | 2026-06-09 |

### B) Definition of baseline (for comparison)

| ID | Subtask | Owner(s) | Status |
|---|---|---|---|
| **B1** | Behavioural simulation cycle-count baseline (`mem_snoop_match.CLK_COUNT`) | **Daniel + Rishi** | ✅ done — 59,560 cycles, ciphertext PASSED (see `BASELINE.md`) |
| **B2** | OOC synthesis baseline (LUTs / regs / DSPs / WNS, core-only) | **Daniel + Rishi** | ✅ done — 5,691 LUTs / +5.513 ns WNS |
| **B3** | Post-implementation baseline (full `riscv_wrapper`, routed, area + timing + power) | **Rishi** | ✅ done 2026-05-06 — see `baselines/post-impl-2026-05-06/README.md` |
| **B4** | Static profiling — instruction counts per AES function from `objdump` | **Daniel** | ✅ done — `PROFILING.md` § 1–6 |
| **B5** | Dynamic profiling — `mcycle` CSR brackets per AES phase | **Daniel** | ✅ done 2026-05-02 — `mix_columns` = 83.8 % of cycles |

### C) Validation and measurements (during Phase 2)

| ID | Subtask | Owner(s) | Effort | Target completion |
|---|---|---|---:|---|
| **C1** | After every RTL change: re-run baseline AES simulation, confirm `Test PASSED`, capture cycle count and compare to 59,560 | **Sathya + Hruday** | continuous | continuous |
| **C2** | After every RTL change: re-run OOC synthesis, capture LUT/reg/DSP delta and WNS impact | **Rishi** | per iteration | continuous |
| **C3** | Generate full bitstream after each successful sim+synth iteration; pull `riscv_wrapper.bit` to a teammate's laptop | **Rishi** | per iteration | continuous |
| **C4** | Upload bitstream to PYNQ-Z1 via Jupyter; run the `base_riscy.ipynb` notebook; verify wall-clock AES output matches simulation | **Rishi + Daniel** | ~6 h per iteration | 2026-06-09 |
| **C5** | Re-run dynamic profiling after `aes32esmi` lands; confirm `mix_columns` share collapses as predicted (target < 10 %) | **Daniel** | ~4 h | 2026-05-30 |
| **C6** | Final-iteration benchmark suite: cycle count + ciphertext check on multiple AES test vectors | **Sathya** | ~6 h | 2026-06-09 |
| **C7** | Final report write-up + slides + demo script + archive (RTL + LLVM mods + scripts) | **All 5** | ~15 h shared | 2026-06-12 |

### Cross-track dependencies

```
B1..B5 (done)
   └→ A1, A2  (decoder + ALU)         <─── C1 sim, C2 synth
        └→ A3 (GAS asm exposure)
             └→ A4 (LLVM intrinsic) ──┐
             └→ A5 (loop unroll)   ───┤
                                       ├→ A6 (super-instruction)
                                       │      └→ C3 bitstream → C4 PYNQ
                                       └→ C5 dynamic re-profile
                                              └→ C6 benchmark suite
                                                     └→ C7 report + demo
```

### Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Rebuilding LLVM in `$HOME` on shared server runs out of disk | medium | high (blocks A4) | Land A3 (inline-asm) first, gives correct cycle counts without LLVM rebuild; only attempt A4 once A3 confirms the win is worth it |
| `custom-0` opcode collides with existing PULP / Xpulp encodings in CV32E40P | low | medium | Cross-check against `cv32e40p_pkg.sv` opcode tables; RISC-V reserves `custom-0` so only PULP-internal users could collide |
| Adding combinational SBox + MixColumns to ALU eats OOC slack | medium | medium | Have +5.513 ns headroom (`BASELINE.md` § 2.2). If WNS goes negative after first impl, pipeline the AES op across two cycles |
| Server overload during week-of-deadline | high | low | Pre-build bitstream early; intermediate report doesn't depend on FPGA |
| Teammate availability gaps (already happened: Vishnu can't make Friday lab in person) | high | low | A1, A2 can proceed in parallel; integration via git submodule + helper scripts already in place |

---

## Q5 — Planning: Gantt chart and milestones

### Gantt chart

```
Week-of (Fri →Thu)        |W1 Apr24-30|W2 May01-07|W3 May08-14|W4 May15-21|W5 May22-28|W6 May29-Jun04|W7 Jun05-11|W8 Jun12  |
═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
PHASE 1 — bring-up + plan
B1 sim baseline           |███████████|           |           |           |           |              |           |          |
B2 OOC baseline           |███████████|           |           |           |           |              |           |          |
B4 static profiling       |███████████|           |           |           |           |              |           |          |
B5 dynamic profiling      |           |███████████|           |           |           |              |           |          |
B3 post-impl baseline     |           |█████      |           |           |           |              |           |          |
Q1-Q5 intermediate report |           |     ██████|███        |           |           |              |           |          |
                          |           |           | ▲ DUE 5/8 |           |           |              |           |          |
PHASE 2 — implement + evaluate
A1 aes32esi RTL           |           |           |   ████████|███████████|██         |              |           |          |
A2 aes32esmi RTL          |           |           |   ████████|███████████|██         |              |           |          |
C1/C2 cont. sim+synth     |           |           |   ████████|███████████|███████████|██████████████|███████████|          |
A3 GAS asm exposure       |           |           |           |           | ██████    |              |           |          |
A4 LLVM intrinsic         |           |           |           |           |     ██████|██████████    |           |          |
A5 LLVM loop unroll       |           |           |           |           |     ██████|██████        |           |          |
A6 super-instruction      |           |           |           |           |        ███|██████████████|██████     |          |
C3 bitstream gen          |           |           |           |           |   ▲       |   ▲          |   ▲       |          |
C4 PYNQ verification      |           |           |           |           |       ▲   |       ▲      |       ▲   |          |
C5 dynamic re-profile     |           |           |           |           |       ████|              |           |          |
C6 benchmark suite        |           |           |           |           |           |              |█████      |          |
C7 report + slides + demo |           |           |           |           |           |              |  ████████ |██████    |
                          |           |           |           |           |           |              |           |▲ DUE 6/12|
```

### Milestones

- **M1 — 2026-05-08 (Fri, end of W2):** Intermediate report submitted on Brightspace. Phase 1 closed: simulation + OOC + post-impl baselines all measured and documented; profiling shows `mix_columns` is 83.8 % of cycles.
- **M2 — 2026-05-23 (Sat, end of W4):** `aes32esi` and `aes32esmi` decoded + executed in RTL; `Test PASSED` on existing simulation flow with the inline-asm path.
- **M3 — 2026-06-02 (Tue, mid W6):** LLVM toolchain emits both new instructions via intrinsics; loop-unroll pass active; cycle count measured and within 25 % of the projected ~17,000.
- **M4 — 2026-06-09 (Tue, mid W7):** Super-instruction implemented in RTL + LLVM; full encryption cycle count measured and within 25 % of the projected ~12,000; bitstream successfully verified on PYNQ-Z1.
- **M5 — 2026-06-12 (Fri, end of W8):** Final source archive submitted, presentation slides ready, demo script rehearsed.
- **M6 — Weeks 25–26:** 60-min final slot per group (20-min presentation + 10-min demo + 20-min Q&A).

---

## Source documents underpinning this report

All measurements cited here are reproducible from the artifacts in this repo:

- [`CLAUDE.md`](./CLAUDE.md) — project context, server setup, toolchain paths
- [`BASELINE.md`](./BASELINE.md) — measured cycle / OOC area / OOC timing baseline
- [`baselines/post-impl-2026-05-06/README.md`](./baselines/post-impl-2026-05-06/README.md) — measured post-impl area / timing / power baseline (full design)
- [`PROFILING.md`](./PROFILING.md) — static + dynamic profiling, methodology, limits
- [`PROGRESS.md`](./PROGRESS.md) — what's done, what's next, deadlines
- [`profiling-instrumentation/`](./profiling-instrumentation/) — instrumented `main.c` and `zynq_tb.sv` source snapshots
- [`references/`](./references/) — Kassimi/Taouil 2026 (side-channel) and Pan 2021 (super-instruction) papers, with notes
- [`drafts/`](./drafts/) — team's working text (Hruday's quiz draft 2026-05-08)
- `pdp-project-24/` (git submodule → GitLab) — RTL + C sources, course-tracked

## References

1. RISC-V International, *RISC-V Cryptography Extensions Volume I: Scalar & Entropy Source Instructions*, v1.0.1 (ratified 2022). https://github.com/riscv/riscv-crypto
2. **Pan L., Tu G., Liu S., Cai Z., Xiong X.**, *"A Lightweight AES Coprocessor Based on RISC-V Custom Instructions"*, Security and Communication Networks, Vol. 2021, Article 9355123, 30 December 2021. DOI: 10.1155/2021/9355123. (`references/pan-2021-aes-coprocessor.pdf`)
3. **Kassimi A., Aljuffri A., Larmann C., Hamdioui S., Taouil M.**, *"Secure Implementation of RISC-V's Scalar Cryptography Extension Set"*, Cryptography (MDPI) 10(1):6, 17 January 2026. DOI: 10.3390/cryptography10010006. (`references/kassimi-2026-secure-zkne-dom.pdf`)
4. OpenHW Group, *CV32E40P User Manual*. https://docs.openhwgroup.org/projects/cv32e40p-user-manual/
5. Gautschi M. et al., *"Near-Threshold RISC-V Core With DSP Extensions for Scalable IoT Endpoint Devices"*, IEEE TVLSI 2017. (Original RI5CY / PULP-Platform reference for CV32E40P's lineage.)
6. *RISC-V Zkne 32-bit AES Encryption Instructions*, RISC-V Onomicon. https://riscvonomicon.github.io/book/extensions/zk/zkned/32bit.html
7. *LLVM Loop Unrolling*, LLVM project documentation. https://llvm.org/docs/LoopTerminology.html#loop-unrolling
