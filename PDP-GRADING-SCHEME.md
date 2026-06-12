# PDP Grading Scheme (CESE4040, Q4 2025–2026)

Markdown digest of `PDP-Grading-Scheme.pdf` (official course document, 6 pages).
Use this as the checklist when preparing the final presentation, demo, and
submission archive.

## 1. Overview

Final grade per student = **group grade + individual adjustment**, clamped to
[1, 10], rounded to the nearest half point. Minimum **6.0** to pass.

| Component | Description |
|---|---|
| Group grade | Quality of the project as a whole: presentation, demo, Q&A, submitted artefacts |
| Individual adjustment | ±1 point total: individual Q&A performance (±0.5) + Buddy Check peer evaluation (±0.5). Applied only when group grade ≥ 6 |

## 2. Mandatory requirements (gate)

All four must be **functional and demonstrated during the final examination**:

1. Baseline system runs: software AES executes correctly on the unmodified RISCY core (simulation and/or FPGA).
2. Profiling/bottleneck analysis of the baseline has been performed and documented.
3. `aes32esi` and `aes32esmi` are implemented in the RISCY core and produce correct encryption output.
4. The LLVM built-in loop-unrolling pass is applied and the unrolled code produces correct output.

- All four met → **base group grade 6**; the rubric below determines anything above 6.
- Any one missing → **group grade 5 (fail)** for all members, no individual adjustment.

## 3. Group grade rubric (beyond the mandatory part)

Each criterion scored 1–4 (Unsatisfactory / Satisfactory / Good / Excellent).

| # | Criterion | Weight |
|---|---|---|
| C1 | Suitability of the proposed solution | 20% |
| C2 | Quality of implementation | 25% |
| C3 | Depth of results and analysis | **30%** |
| C4 | Presentation, demo, and Q&A | 25% |

Group grade = 6 + (W − 1) × (4/3), where W = 0.20·C1 + 0.25·C2 + 0.30·C3 + 0.25·C4.
Reference points: all-Unsatisfactory → 6.0, all-Satisfactory → 7.3, all-Good → 8.7, all-Excellent → 10.0.

### C1 — Suitability of the proposed solution (20%)

- **Satisfactory:** improvement relevant, target metric defined, connected to a baseline analysis; some related work mentioned.
- **Good:** bottleneck→improvement connection clearly argued; state of the art surveyed with reasonable depth; approach positioned relative to existing solutions; hypothesis stated; evaluation methodology outlined.
- **Excellent:** critical understanding of the state of the art (comparing approaches, justifying the specific choice); hypothesis specific, testable, quantified; originality or strong technical insight.

### C2 — Quality of implementation (25%)

- **Satisfactory:** at least one extension attempted and partially functional; limitations acknowledged; code readable; group can explain the approach.
- **Good:** extensions functional and correct; reasonably structured code, meaningful naming, comments; limitations identified and documented rather than hidden.
- **Excellent:** non-trivial scope; clean modular structure, reusable components, systematic verification (dedicated testbenches, test vectors); edge cases and failure modes identified and handled; mastery of Vivado/LLVM beyond basic usage; publishable approach.

### C3 — Depth of results and analysis (30%, highest weight)

- **Satisfactory:** baseline defined; ≥1 relevant metric; methodology described; mostly descriptive analysis; negative results reported but not explained.
- **Good:** multiple relevant metrics; sound, clearly described methodology; reasonable interpretation connecting observations back to design decisions; fair and quantitative baseline comparisons.
- **Excellent:** explains *why* results are as observed (which pipeline stage, which memory access pattern); trade-offs explicitly discussed (area vs speed, code size vs latency); failed ideas get a well-reasoned, evidence-grounded explanation; results compared against state-of-the-art references; methodology reproducible by an independent reader.

> **Note:** a well-analyzed negative result is valued **higher** than a positive
> result with no analysis. The goal is to demonstrate understanding, not to
> guarantee speedup.

### C4 — Presentation, demo, and Q&A (25%)

- **Satisfactory:** all required topics covered, understandable; demo runs; Q&A mostly correct but sometimes vague.
- **Good:** clear narrative from problem to results; slides visually clean and **support (rather than repeat) the spoken content**; convincing, smooth demo; accurate Q&A beyond the slides.
- **Excellent:** complex ideas explained clearly; design decisions justified rather than just described; narrative anticipates likely questions; demo well-prepared with clear **before/after comparisons**; every member shows confident command of the **full** project, not just their own part; on-the-spot reasoning about hypothetical variations.

### Required presentation topics (20-minute talk)

1. Problem definition
2. Design overview
3. Implementation details
4. Results and discussion/analysis (linked to metrics defined in the intermediate report)
5. Potential future work
6. Short reflection on group performance during the project

**Slides must be submitted on Brightspace one week before the final examination
date.** Minor changes after submission are permitted.

## 4. Individual adjustment (±1)

- **Q&A (±0.5):** examiners direct questions at individual students; assesses understanding of (a) the overall project and (b) the student's own contribution.
- **Buddy Check (±0.5):** peer ratings on Communication, Effort/Quality of Work, Commitment/Reliability (5-point scale). Adjustment from deviation vs group mean: ≥ +1.0 above → +0.5; within ±1.0 → 0; ≤ −1.0 below → −0.5. Self-assessment excluded.

## 5. Grade calculation summary

1. Mandatory gate: any missing → group grade 5 (fail) for all. Stop.
2. All met → base 6.
3. Score C1–C4 (1–4 each).
4. W = 0.20·C1 + 0.25·C2 + 0.30·C3 + 0.25·C4.
5. G = 6 + (W − 1) × (4/3), rounded to nearest 0.5.
6. A = Q&A (±0.5) + Buddy Check (±0.5).
7. Final = G + A, clamped to [1, 10], rounded to nearest 0.5; ≥ 6.0 to pass.

## 6. Important notes (from the course team)

- An idea that does not produce the expected improvement is **not penalized**
  as long as the group provides a well-reasoned analysis of why.
- The **number** of extensions is not a grading factor; one thoroughly
  implemented and analyzed improvement can outscore multiple shallow ones.

## Implications for our slides (Group 24)

- C3 is 30%: every results slide needs quantitative before/after vs **our own
  baseline** (59,560 cycles; TVLA |t| = 44 unprotected sim; CW305 hardware
  numbers), with the *why* spelled out.
- The CPA "0/16 bytes recovered" on software/Zkne is a *well-analyzed negative
  result* (PGE trending to 0-3, traces insufficient): present it as evidence of
  leakage plus an honest trace-budget analysis, exactly what C3-Excellent rewards.
- C1 rewards positioning vs state of the art: cite Kassimi et al. 2026
  (Dr. Taouil's group) for DOM and Pan et al. 2021 for the super-instruction.
- C4 rewards before/after comparisons and slides that support rather than
  repeat the talk: keep slide text minimal, put numbers in tables/plots.
