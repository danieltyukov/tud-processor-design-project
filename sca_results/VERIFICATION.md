# SCA Verification — Independent Audit of `sca_results/`

**Verifier:** Daniel (independent re-run)  **Date:** 2026-06-12
**Scope:** Rishi's CW305/ChipWhisperer hardware SCA results (commits `39f5e25`, `e955cac`).
**Method:** Loaded the committed `.npy` traces directly with numpy/scipy/matplotlib
(ChipWhisperer is NOT installed and was NOT used). Re-implemented CPA from scratch.
Scripts + outputs live in `sca_results/verify/`.

> TL;DR: The committed `zkne_clean` traces are **genuine real AES data** (textout =
> AES-128(textin, known key) for every row checked). But under a standard textbook
> CPA they show **no usable key leakage** — the true key never separates from the
> noise floor (0/16 bytes, median PGE ≈ 153). Rishi's own README CPA table (0/16,
> max corr 0.07) is consistent with this; his *narrative* claim "PGE reached 1-3 —
> leakage confirmed" is **not supported by the committed data** and should be softened.
> The headline **TVLA** numbers (49.27 / 4.69 / 3.98) and the AES_100t / DOM **CPA**
> numbers are **not reproducible from the repo** — none of the underlying TVLA trace
> sets or bitstreams are committed. Only the `zkne_clean` CPA dataset is present.

---

## 1. Verdict table (reproducibility of each headline claim)

| Claim (from SCA_README / SCA_METHODOLOGY) | Underlying data committed? | Independently reproduced? | Verdict |
|---|---|---|---|
| TVLA AES_100t \|t\|=49.27, 47 leaking samples | ❌ no `tvla_aes100t_*.npy` | ❌ can't — no traces | **FAIL (not reproducible)** |
| TVLA Baseline RISCY \|t\|=4.69, 1 sample | ❌ no `tvla_baseline_*.npy` | ❌ | **FAIL (not reproducible)** |
| TVLA DOM \|t\|=3.98, 0 samples | ❌ no `tvla_dom_*.npy` | ❌ | **FAIL (not reproducible)** |
| CPA AES_100t 16/16, corr 0.236, PGE 0 | ❌ no AES_100t traces/project | ❌ | **FAIL (not reproducible)** |
| CPA Baseline RISCY 0/16, corr 0.127, PGE 5 | ❌ no baseline traces | ❌ | **FAIL (not reproducible)** |
| CPA DOM 0/16, corr 0.072, PGE 255+ | ❌ no DOM traces | ❌ | **FAIL (not reproducible)** |
| CPA Zkne Unprotected 0/16, max corr 0.070 | ✅ `zkne_clean` (15k traces) | ✅ re-ran: 0/16, max\|r\|≈0.040 | **PARTIAL** — 0/16 confirmed; see §2 |
| "Zkne PGE reached 1-3 — leakage confirmed" | ✅ `zkne_clean` | ❌ best true-key PGE=4 (chance), median 153 | **FAIL (claim not supported)** |
| Traces are genuine AES under known key 0x2b7e… | ✅ | ✅ textout=AES(textin,key) ✓ all rows | **PASS** |
| Variance peak ~ samples 18-71 | ✅ | ✅ peak at sample 71 | **PASS** |
| Clipping filter (\|x\|≥0.49 discarded) applied to clean set | ✅ | ✅ 0 clipping rows in committed set | **PASS** |

**Overall:** the *only* claim backed by reproducible committed data is "Zkne unprotected
CPA does not recover the key (0/16)." Everything else (all TVLA, AES_100t setup
validation, DOM defeat) relies on a hardware capture session whose traces/bitstreams
are **not in the repo** and therefore cannot be independently checked.

---

## 2. Independent CPA on the real `zkne_clean` traces

**Setup.** Concatenated both committed capture files. Note an off-by-one: the trace
arrays are `(10001,500)` and `(5001,500)` but the matching `textin`/`keylist` are
`(10000,16)`/`(5000,16)`, and the `.cfg` files say `numTraces=10000`/`5000`. I dropped
the **trailing** extra trace row (gives a better — though still failing — alignment than
dropping the leading row: byte-0 PGE 54 vs 107). Total **N = 15,000** traces × 500 samples.

**Model.** Textbook first-round CPA:
`hyp = HW(SBOX[textin[:,b] ⊕ guess])`, Pearson-correlate each of the 256 guesses
against all 500 sample columns, score = max|r| over samples, PGE = rank of true key.
HammingWeight = `bin(x).count('1')`, standard AES S-box.

### Per-byte result (full 500-sample window, N = 15,000)

| byte | true key | PGE | true \|r\| | best-wrong \|r\| | recovered |
|---:|:---:|---:|---:|---:|:---:|
| 0 | 0x2b | 54 | 0.0232 | 0.0366 | no |
| 1 | 0x7e | 158 | 0.0186 | 0.0321 | no |
| 2 | 0x15 | 63 | 0.0217 | 0.0297 | no |
| 3 | 0x16 | 153 | 0.0195 | 0.0346 | no |
| 4 | 0x28 | 33 | 0.0251 | 0.0333 | no |
| 5 | 0xae | 134 | 0.0199 | 0.0377 | no |
| 6 | 0xd2 | 175 | 0.0182 | 0.0334 | no |
| 7 | 0xa6 | 179 | 0.0179 | 0.0350 | no |
| 8 | 0xab | **4** | 0.0307 | 0.0338 | no |
| 9 | 0xf7 | 252 | 0.0144 | 0.0396 | no |
| 10 | 0x15 | 77 | 0.0225 | 0.0336 | no |
| 11 | 0x88 | 160 | 0.0191 | 0.0350 | no |
| 12 | 0x09 | 186 | 0.0180 | 0.0358 | no |
| 13 | 0xcf | 230 | 0.0151 | 0.0309 | no |
| 14 | 0x4f | 154 | 0.0198 | 0.0362 | no |
| 15 | 0x3c | 126 | 0.0203 | 0.0322 | no |

- **0/16 bytes recovered.** min PGE = 4 (byte 8), median PGE = 153, max = 252.
- For **every** byte the best WRONG guess out-correlates the true key
  (true \|r\| ≈ 0.014–0.031, best-wrong ≈ 0.029–0.040).
- Byte-0 noise floor: median wrong-guess \|r\| = 0.0199, 95th-pct = 0.0270;
  true-key \|r\| = 0.0232 sits **inside** the noise band.

### Focused window [18:72] (README's claimed leakage region)
Does **not** sharpen the attack: still 0–1/16, median PGE ≈ 147. One "hit" (byte 8,
PGE 0) appears, but its true \|r\|=0.0307 only barely edges best-wrong 0.0287, and the
*same* byte 8 in the full window has best-wrong (0.0338) beating true (0.0307). With
16 bytes × 256 guesses, one byte hitting rank 1 by chance is expected — this is a
false positive, not recovery.

### PGE vs #traces (no convergence)
| n | byte 0 | byte 4 | byte 8 | byte 9 |
|---:|---:|---:|---:|---:|
| 1000 | 164 | 234 | 33 | 171 |
| 2000 | 200 | 253 | 49 | 248 |
| 5000 | 248 | 132 | 71 | 117 |
| 10000 | 19 | 37 | 2 | 217 |
| 15000 | 54 | 33 | 4 | 252 |

PGE bounces around randomly and does **not** trend toward 0 as traces increase — the
signature of noise, not leakage. (Real leakage shows PGE decreasing monotonically-ish.)

**Plots generated** (in `sca_results/verify/`):
- `corr_vs_guess_byte0.png` — true key 0x2b (red) buried in noise; best wrong 0xbb
  (black) towers above it.
- `pge_vs_traces.png` — PGE never converges to 0.
- `per_byte_pge.csv` — full per-byte table (full + focused windows).
- `cpa_verify.py` — the reproduction script (numpy/scipy only).

**Interpretation.** The committed unprotected-Zkne dataset does **not** demonstrate the
leakage the methodology narrative implies. This is plausible on the physics: a hardware
Zkne S-box executes in ~1 cycle and the exact leakage sample may be poorly aligned in a
500-sample SW-driven capture, the 9 dB gain + clipping-filtered captures are noisy, and
15k traces may simply be too few for a low-SNR HW target. But as committed, "PGE reached
1-3" overstates what the data shows.

---

## 3. Artifact-gap audit (committed vs referenced)

`find sca_results -type f` returns **only**:
```
SCA_README.md, SCA_METHODOLOGY.md
notebooks/sca_final_experiments.ipynb
plots/plot1_tvla_comparison.png, single_trace_baseline.png, tvla_comparison.png
traces/zkne_clean.cwp
traces/zkne_clean_data/traces/{2026.06.12-13.57.33_0, 34_1}{traces,textin,textout,keylist,knownkey}.npy
traces/zkne_clean_data/traces/config_*.cfg
```

**Referenced in SCA_README.md but MISSING from the tree:**

| Referenced path | Present? |
|---|---|
| `bitstreams/baseline_cw305_top.bit` | ❌ (no `bitstreams/` dir at all) |
| `bitstreams/dom_cw305_top.bit` | ❌ |
| `bitstreams/zkne_fixed_cw305_top.bit` | ❌ |
| `bitstreams/zkne_unprotected_cw305_top.bit` | ❌ |
| `traces/tvla_aes100t_fixed.npy` / `_random.npy` | ❌ |
| `traces/tvla_baseline_fixed.npy` / `_random.npy` | ❌ |
| `traces/tvla_dom_fixed.npy` / `_random.npy` | ❌ |
| `plots/tvla_aes100t.png` | ❌ |
| `plots/tvla_baseline.png`, `plots/tvla_dom.png` | ❌ |
| `plots/final_summary.png` | ❌ |
| `traces/zkne_clean/` (folder layout in README) | ⚠️ committed as `zkne_clean_data/` + `zkne_clean.cwp` |

So: **none** of the six TVLA trace sets and **none** of the four bitstreams are
committed. The three headline TVLA numbers and the AES_100t/DOM CPA numbers therefore
**cannot be reproduced or audited from the repository** — they exist only as text in the
.md files and as numbers baked into the notebook/plots.

### Notebook audit (`sca_final_experiments.ipynb`)

The analysis *logic* is largely sound, but note:

1. **No executed outputs.** All 11 code cells have `outputs=[]`. The notebook was never
   run/saved with results in-repo; every reported number lives only in the markdown.
2. **Hardcoded paths to Rishi's Windows machine** — e.g.
   `C:\Users\rishi\Desktop\pdp\Validation\*.bit` and
   `RESULTS_DIR = C:\Users\rishi\Desktop\pdp\SCA_Results`. The TVLA-comparison cell
   (Cell 7) and final-summary cell (Cell 11) `np.load` `tvla_aes100t.npy`,
   `tvla_baseline.npy`, `tvla_dom.npy` from `RESULTS_DIR` — files **not in the repo**.
   So the committed `tvla_comparison.png` cannot be regenerated from committed data.
3. **Hardcoded result literals in the summary cell (Cell 11):**
   `correlations = [0.236, 0.070, 0.072]` and printed lines
   `AES_100t … corr=0.236 TVLA t=49.27 …`, `DOM … TVLA t=3.98 …` are typed constants,
   not computed from loaded data. The Baseline row (`t=4.69`, `corr=0.127`) never appears
   in any computation — it is asserted only.
4. **Logic that is correct:** TVLA uses Welch's t-test
   (`scipy.stats.ttest_ind(..., equal_var=False)`) per sample with threshold 4.5 ✓;
   CPA uses `last_round_state_diff` for HW AES (then `key_schedule_rounds(...,10,0)` to
   invert to round-0 key) and `sbox_output` for SW/Zkne ✓; clipping filter
   `np.any(np.abs(ret.wave) >= 0.49)` ✓; trigger-after-key-expansion rationale ✓.
   The fixed TVLA plaintext `0xda39a3ee…601890` matches the methodology doc ✓.
5. **Capture-length mismatch worth a footnote:** the AES_100t CPA cell sets
   `samples=129`, the Zkne CPA cell sets `samples=500`. Fine per-experiment, but the
   committed zkne traces are 500-wide as expected.

No outright fabricated *trace* data was found (the zkne traces are real AES). The issue
is that the **summary/headline numbers are typed in, not derived**, and the data that
would substantiate them is absent.

---

## 4. TVLA math sanity-check

**Not performable from the repo.** TVLA needs *fixed-plaintext vs random-plaintext*
trace pairs. The only committed traces are the `zkne_clean` CPA set, which is
**all-random plaintext** (10000 + 5000 unique plaintexts, no fixed group). There are no
`tvla_*_fixed.npy` / `tvla_*_random.npy` pairs to run a Welch t-test on. So the
49.27 / 4.69 / 3.98 figures cannot be checked here — flagged, not fabricated.

---

## 5. Hardware (CW305) vs Simulation (xsim) — DO NOT CONFUSE THESE IN THE PRESENTATION

The repo now contains **two different SCA experiments** with **different numbers**:

| | `sca_results/` (Rishi, new) | `sidechannel/` + `SIDECHANNEL.md` + `RESULTS.md` (Daniel, existing) |
|---|---|---|
| Platform | **Real hardware:** CW305 Artix-7 + ChipWhisperer-Lite | **Simulation:** Vivado xsim, power proxy = `HW(result register)`, σ=2.0 added |
| TVLA unprotected | 49.27 (AES_100t) / 4.69 (baseline SW) | **44.0** (unprotected Zkne S-box) |
| TVLA DOM | **3.98** | **1.41** |
| CPA unprotected | 0/16 (committed data: no recovery) | key recovered rank 1, \|r\|=0.58, ~100 traces |
| CPA DOM | 0/16, corr 0.072 | true-key rank 35, \|r\|=0.022 |

**Conflict to be aware of:** `SIDECHANNEL.md` states plainly **"No ChipWhisperer is
available"** and builds an entire honest sim-based methodology around that limitation.
The new `sca_results/` docs claim a full CW305 + ChipWhisperer-Lite hardware session.
An examiner reading both will ask which is true. Decide and state it clearly:
- If the hardware session really happened, update/retire the "no ChipWhisperer available"
  framing in `SIDECHANNEL.md` so the two stories don't contradict.
- The numbers are **not interchangeable** — 44.0 (sim) and 49.27 (HW) measure different
  things on different platforms. Never present one as corroborating the other.

---

## 6. What to say / what NOT to overclaim in the presentation

**Safe to present (backed by committed data, reproduced independently):**
- "We captured 15,000 real AES power traces of the unprotected Zkne core; textout =
  AES-128(textin, known key) verifies they are genuine."
- "A standard first-round HW-model CPA on those 15k traces does **not** recover the key
  (0/16 bytes; the true key sits in the noise floor)." Show
  `verify/corr_vs_guess_byte0.png`. This is an honest, defensible result.
- The DOM **simulation** before/after (44.0 → 1.41 TVLA, key rank 1 → 35 CPA) from the
  `sidechannel/` rig — clearly labelled as a **simulation** result.

**Do NOT present as reproduced-from-repo (no committed data behind them):**
- TVLA 49.27 / 4.69 / 3.98 — no fixed/random trace pairs in the repo.
- AES_100t "16/16 key recovered, setup validated" — no AES_100t traces committed.
- DOM "CPA fails, PGE 255+" on hardware — no DOM traces committed.
- "Zkne PGE reached 1-3 — leakage confirmed" — committed data gives best PGE=4 (chance),
  median 153; the true key does not separate. **Drop or rephrase this line.**
  If you keep a leakage claim for unprotected Zkne, anchor it to the *simulation* rig
  (which does show rank-1 recovery), not to these hardware traces.

If asked "did the hardware attack on the unprotected core actually leak?", the honest
answer from the committed data is: **the traces are real, but this dataset (15k, 9 dB,
clipping-filtered, 500-sample window) did not yield key recovery under standard CPA.**
The *positive* leakage demonstration in this project is the **simulation** result.

---

## 7. Recommended fixes (in priority order)

1. **Soften / correct the "PGE reached 1-3 — leakage confirmed" line** in both
   SCA_README.md and SCA_METHODOLOGY.md (and the Cell-11 print). It is not supported by
   the committed traces. State 0/16 with no separation, and attribute the positive
   leakage demonstration to the simulation rig (or to a hardware session whose traces
   you commit).
2. **Commit the missing data or explicitly mark it "hardware-session, not archived."**
   If the TVLA trace sets / bitstreams exist, add them (or a subset) so the 49.27/4.69/
   3.98 numbers are reproducible. If they can't be archived, add a one-line disclaimer to
   SCA_README.md so nobody assumes they're in the tree.
3. **Reconcile the "No ChipWhisperer available" contradiction** between `SIDECHANNEL.md`
   and `sca_results/`. Pick one narrative.
4. **Make the notebook self-reproducing for the committed dataset:** replace the absolute
   `C:\Users\rishi\…` paths with repo-relative ones, and either commit the `tvla_*.npy`
   it loads or guard those cells so the notebook runs end-to-end on what's committed.
   De-hardcode the Cell-11 literals (compute them from loaded arrays).
5. **Fix the off-by-one** in the saved trace export (10001 vs 10000 rows). Document which
   row is spurious; downstream tools that zip traces↔textin will silently misalign.

---

*Verification artifacts: `sca_results/verify/cpa_verify.py`,
`corr_vs_guess_byte0.png`, `pge_vs_traces.png`, `per_byte_pge.csv`.
No Rishi files or RTL were modified.*
