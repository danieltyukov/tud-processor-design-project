# Side-Channel Track — Group 24

This document is the project-side record of the side-channel resilience track
(Daniel's individual deliverable). It is the report-ready companion to
`BASELINE.md` and `PROFILING.md`. Methodology, code, and measurements all live
in `sidechannel/`; design rationale is in
`docs/superpowers/specs/2026-05-25-sidechannel-dom-design.md`.

## 1. What we built

A complete, simulation-based side-channel attack pipeline, plus a
DOM-protected replacement for the Zkne AES S-box that survives it.

| Component | Path | Role |
|---|---|---|
| Leakage harness (unprotected) | `sidechannel/tb/tb_zkne_leak.sv` | Drives `cv32e40p_zkne`, captures result register, logs CSV |
| Leakage harness (DOM) | `sidechannel/tb/tb_zkne_leak_dom.sv` | Same, but on the DOM-masked S-box with fresh per-trace mask |
| Tower-field golden model | `sidechannel/dom/sbox_tower_model.py` | Python derivation + brute-force verification of GF((2⁴)²) constants |
| Unmasked tower-field S-box | `sidechannel/dom/aes_sbox_tower.sv` | Same algebra, no LUT in the GF(2⁴) inverse |
| **DOM-masked tower-field S-box** | `sidechannel/dom/aes_sbox_tower_dom.sv` | The actual countermeasure: 2-share, registered DOM-AND gates, 4-cycle pipeline |
| Functional tests | `sidechannel/tb/tb_sbox_tower*.sv` | Exhaustive 256-input check (unmasked) + random sweep (DOM) |
| CPA / TVLA analyzers | `sidechannel/analysis/cpa.py`, `tvla.py` | Correlation power analysis + Welch fixed-vs-random t-test |
| Drivers + scripts | `sidechannel/sim/*.sh`, `scripts/push-sca.sh` | Headless Vivado xsim drivers on the server |

## 2. Attack model and constraints

**No ChipWhisperer is available**, so "power" is a simulation-based proxy:
`HW(captured_result_register)`. The testbench runs in Vivado xsim on the group
server; analysis runs locally in Python (numpy/scipy/matplotlib). This is the
standard fallback in academic SCA work when hardware probes aren't on hand and
is what the Kassimi 2026 paper used at a higher fidelity (real CW305 traces
plus formal verification with SILVER).

**Limitation we are honest about**: the simulated power model captures the
data-dependent component of switching power at the captured register but does
not include analog effects (glitches in unmasked combinational paths,
capacitive coupling, supply ringing). A "TVLA pass" in this rig is **necessary
but not sufficient** for hardware security; it is the correct yardstick for an
RTL-level demonstration of DOM principles.

## 3. Methodology

For both the unprotected baseline and the DOM-protected design:

- **CPA**: 20,000 random plaintext bytes XORed with a hidden key `0x2b`,
  Hamming-weight hypothesis `HW(sbox[pt ⊕ guess])`, Pearson correlation across
  all 256 guesses; Gaussian noise σ = 2.0 added in Python so traces-to-
  disclosure is a meaningful curve rather than a single-trace break.
- **TVLA**: 40,000 traces, interleaved fixed-plaintext vs random-plaintext
  groups, Welch t-test on `HW(captured)`. Threshold |t| > 4.5 indicates
  first-order leakage.

The *same* analysis code runs against both rigs — the CSV format is identical.
This makes the before/after a clean apples-to-apples comparison.

## 4. Results

### 4.1 Baseline — unprotected Zkne S-box (Hruday's RTL)

| Metric | Value |
|---|---|
| CPA recovered key byte | **0x2b** (rank 1/256) |
| Top-guess correlation \|r\| | **0.58** |
| Wrong-guess noise floor | ≤ 0.14 |
| Traces to disclosure | **~100** |
| TVLA Welch \|t\| | **44.0** (threshold 4.5) |
| TVLA crosses threshold at | ~600 traces |
| Verdict | **First-order leakage detected; key trivially recoverable** |

Plots: `sidechannel/out/cpa_corr_vs_guess.png`, `cpa_convergence.png`,
`tvla_tcurve.png`.

### 4.2 DOM-protected — `aes_sbox_tower_dom.sv`

| Metric | Value |
|---|---|
| CPA recovered key byte | `0x37` (random guess, **not** the true key) |
| True-key rank | **35 / 256** |
| Top-guess correlation \|r\| | 0.022 |
| True-key correlation \|r\| | 0.011 |
| Traces to disclosure | **Not reached within 20,000 traces** |
| TVLA Welch \|t\| | **1.41** (threshold 4.5) |
| Verdict | **No first-order leakage detected; attack fails** |

Plots: `sidechannel/out/dom_cpa_corr_vs_guess.png`, `dom_cpa_convergence.png`,
`dom_tvla_tcurve.png`.

### 4.3 Before / after summary

| Metric | Unprotected | DOM | Improvement |
|---|---:|---:|---:|
| CPA true-key rank | 1 | 35 | 35× worse for attacker |
| CPA top-guess \|r\| | 0.58 | 0.022 | **26× smaller** |
| TVLA \|t\| | 44.0 | 1.4 | **31× smaller** |
| Above leakage threshold? | Yes (×9.8) | No (×0.3) | passes |

### 4.4 Area and timing cost (OOC synthesis, Vivado 2024.2, xc7z020clg400-1)

| Module | LUTs | FFs | Latency | WNS @ 100 MHz |
|---|---:|---:|---:|---:|
| `aes_sbox_tower` (unmasked, this work) | 32 | 0 | combinational | n/a |
| **`aes_sbox_tower_dom`** (this work) | **182** | **100** | **4 cycles** | **+6.054 ns** |
| **DOM overhead** | **+150 (5.7×)** | **+100** | **+3 cycles** | positive |

Context against the full-system baseline (from `baselines/post-impl-2026-05-06/`,
10,171 LUTs / 8,522 FFs / +28.306 ns @ 20 MHz): integrating this DOM S-box
into the core adds roughly **+1.5 % LUTs** and **+1.2 % FFs**. Kassimi 2026
report +0.39 % area on CV32E40S — our number is higher because they recurse
one level deeper into GF(2²) (where the multiply becomes a free linear op) and
share gates more aggressively across the S-box, while our prototype stops at
GF(2⁴) for clarity. The WNS is solidly positive, so the pipeline does not
violate the 100 MHz constraint, leaving room for the (now multi-cycle)
instruction to be folded into the ALU's existing ready/valid handshake.

## 5. Architecture of the DOM-masked S-box

The AES S-box can be written as `affine(x⁻¹ in GF(2⁸)) ⊕ 0x63`. The
multiplicative inverse is the only nonlinear step, and is what masking has
to protect. The design pipeline:

1. **In-map** (linear GF(2) map): standard byte → tower representation under
   GF((2⁴)²)/`z²+z+λ`, λ = 0x8. Done per share.
2. **Tower inverse** — the work, structured so all nonlinearity lives in five
   GF(2⁴) multipliers, each registered as a **DOM-AND gate**:
   - Stage 1: `ah · al` (one DOM-multiply)
   - Stage 2: build `d = ah²·λ + ah·al + al²`, then `d²`, `d⁴`, `d⁸` (all
     linear); DOM-multiply `m₁ = d² · d⁴`
   - Stage 3: DOM-multiply `m₂ = m₁ · d⁸` → `d¹⁴ = d⁻¹`
   - Stage 4: parallel DOM-multiplies `ph = ah · d⁻¹`, `pl = (ah⊕al) · d⁻¹`
3. **Out-map** (linear): tower inverse → standard byte, folded with the AES
   affine's linear part; XOR with `0x63` on one share only.

Each **DOM-AND gate** computes `c = a · b` where `a = a₀⊕a₁`, `b = b₀⊕b₁`:

```
       c₀ ← (a₀·b₀) ⊕ (a₀·b₁ ⊕ z)      \  registered at the same edge with
       c₁ ← (a₁·b₁) ⊕ (a₁·b₀ ⊕ z)      /  the same fresh random nibble z
```

The register is what makes it **glitch-resistant** — no transient combination
of both shares can propagate forward — and `z` makes each share statistically
independent of the underlying secret. Five GF(2⁴) multipliers × 4 random bits
= **20 bits of fresh randomness per S-box execution**.

The constants (`λ = 0x8`, isomorphism `θ = 0x20`, the two 8×8 GF(2) bit-image
maps) are derived and brute-force verified in `sbox_tower_model.py`. Every
constant matches all 256 entries of the standard AES table before being put
into RTL — there is no hand-derived matrix to be wrong about.

### Constants the RTL bakes in (from the Python golden model)

| Name | Value | Where |
|---|---|---|
| λ (GF(2⁴)) | `4'h8` | norm/inverse formula |
| θ (iso generator) | `8'h20` | only used to derive the maps |
| `in_map` columns | `01 20 46 4c 3c d5 34 e5` | std-byte → tower |
| `out_map` columns | `1f b2 ab 36 52 3e 65 60` | tower-inverse → std-byte (then ⊕ 0x63) |

## 6. How to reproduce

All steps run from the workspace root with the VPN connected.

```bash
# 1. push sources + DUTs to the server
./scripts/push-sca.sh

# 2a. attack the unprotected design (baseline)
./scripts/connect-server.sh \
    'cd ~/sca && ./sim/run_leak_xsim.sh num_traces=20000 key_byte=43 tvla=0 outfile=out/cpa.csv'
./scripts/connect-server.sh \
    'cd ~/sca && ./sim/run_leak_xsim.sh num_traces=40000 tvla=1 fixed_pt=0 key_byte=43 outfile=out/tvla.csv'

# 2b. attack the DOM design
./scripts/connect-server.sh \
    'cd ~/sca && ./sim/run_dom_leak_xsim.sh num_traces=20000 key_byte=43 tvla=0 outfile=out/dom_cpa.csv'
./scripts/connect-server.sh \
    'cd ~/sca && ./sim/run_dom_leak_xsim.sh num_traces=40000 tvla=1 fixed_pt=0 key_byte=43 outfile=out/dom_tvla.csv'

# 3. pull the four CSVs
for f in cpa tvla dom_cpa dom_tvla; do
    ./scripts/fetch-from-server.sh "~/sca/out/${f}.csv" ./sidechannel/out/
done

# 4. attack
cd sidechannel/analysis
python3 cpa.py  --csv ../out/cpa.csv      --true 0x2b --noise 2.0 --out ../out/cpa
python3 tvla.py --csv ../out/tvla.csv     --noise 2.0 --out ../out/tvla
python3 cpa.py  --csv ../out/dom_cpa.csv  --true 0x2b --noise 2.0 --out ../out/dom_cpa
python3 tvla.py --csv ../out/dom_tvla.csv --noise 2.0 --out ../out/dom_tvla
```

To verify the DOM module's *functional correctness* (regardless of leakage),
the standalone exhaustive test:

```bash
./scripts/connect-server.sh 'cd ~/sca && ./sim/run_sbox_dom_xsim.sh'
# expects: DOM SBOX TEST: PASS  (5256/5256 unmasked results match AES)
```

## 7. What this does and does not claim

- ✅ The simulation-based rig detects first-order leakage in the unprotected
  baseline (CPA recovers the key in ~100 traces; TVLA |t| = 44).
- ✅ The DOM-masked S-box defeats the same rig: CPA fails (true key never
  reaches rank 1; |r| = 0.022 vs. 0.58); TVLA stays under 4.5.
- ✅ DOM module is functionally equivalent to the unmasked one across all
  256 inputs and a random sweep of (input, mask, randomness) tuples.
- ❌ This is **not** a guarantee that the design is hardware-secure. The
  simulation power model excludes glitches, coupling, supply effects. A
  hardware-validated claim would need a CW305 board (which we don't have)
  or formal verification with SILVER.
- ❌ The DOM module returns the result as two shares; integration with the
  rest of the AES (which expects a plain byte) would require the software /
  ISA to track masks across instructions, in the manner of Kassimi 2026.
  Within the scope of this project the demonstration is at the unit level.

## 8. References

- Kassimi A., Aljuffri A., Larmann C., Hamdioui S., Taouil M. — *Secure
  Implementation of RISC-V's Scalar Cryptography Extension Set*, Cryptography
  10(1):6, 2026. `references/kassimi-2026-secure-zkne-dom.pdf`
- Gross H., Mangard S., Mendel F. — *Domain-Oriented Masking: Compact Masked
  Hardware Implementations with Arbitrary Protection Order*, TIS 2016.
- Canright D. — *A Very Compact S-Box for AES*, CHES 2005.
- FIPS PUB 197 — *Advanced Encryption Standard*.
