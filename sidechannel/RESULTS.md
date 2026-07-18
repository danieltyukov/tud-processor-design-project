# Side-channel results — baseline (unprotected Zkne)

Measured 2026-05-25 on the unprotected `cv32e40p_zkne` (Hruday's RTL, branch
`adding-aes-rtl`). Simulation-based leakage model: drive plaintexts through the
hardware S-box, capture the result register, power proxy = `HW(result)`. Full
methodology + reproduction in `README.md`; design rationale in
`../docs/superpowers/specs/2026-05-25-sidechannel-dom-design.md`.

## Baseline attack (Phase 2) — the design LEAKS

| Experiment | Setup | Result |
|---|---|---|
| **CPA key recovery** | 20,000 random plaintexts, hidden key byte `0x2b`, `aes32esi` bs=0, Python noise σ=2.0 | **Key recovered, rank 1/256.** \|r\|=0.58 for the true key vs ≤0.14 for every wrong guess. |
| **Traces to disclosure** | same | **~100 traces** to pin the correct key byte as rank 1. |
| **TVLA fixed-vs-random** | 40,000 traces, fixed byte `0x00`, Welch t-test | **\|t\| = 44.0** (threshold 4.5). Crosses 4.5 at ~600 traces. → first-order leakage, unambiguous. |

Plots (in `out/`):
- `cpa_corr_vs_guess.png` — correct key spikes far above the noise floor.
- `cpa_convergence.png` — true-key correlation separates from all wrong keys.
- `tvla_tcurve.png` — \|t\| blows past 4.5 and keeps climbing.

**Interpretation:** the unprotected hardware S-box leaks the key through its
Hamming weight, exactly as predicted by the leakage model. This is the
"correlation to the instruction running" the supervisor asked us to demonstrate,
and it is the reference the DOM-protected module must beat.

## Targets for the protected design (Phase 4)

Re-run the *identical* rig on `cv32e40p_zkne_dom` and expect:

| Metric | Unprotected (baseline) | DOM target |
|---|---|---|
| CPA: true-key rank | 1 / 256 | not rank 1 (lost in noise) |
| CPA: traces to disclosure | ~100 | not reached within the dataset |
| TVLA: max \|t\| | 44.0 | < 4.5 |
| OOC area (LUT/reg) | TBD (synth unprotected first) | report Δ vs Kassimi's +0.39 % |
| OOC timing (WNS) | +5.513 ns slack (BASELINE.md) | must stay positive (2-cycle ok) |

> The σ=2.0 noise is a modelling choice that sets absolute trace counts; what
> matters is the *before/after* comparison at the same σ. We hold σ fixed
> across baseline and DOM runs.
