# Side-Channel Track (Simulation-Based)

A simulation-based side-channel attack pipeline plus a DOM-protected replacement
for the Zkne AES S-box that survives it.

## 1. What we built

| Component | Role |
|---|---|
| Leakage harness (unprotected) | Drives `cv32e40p_zkne`, captures result register, logs CSV |
| Leakage harness (DOM) | Same, on the DOM-masked S-box with a fresh per-trace mask |
| Tower-field golden model | Python derivation and brute-force verification of GF((2⁴)²) constants |
| Unmasked tower-field S-box | Same algebra, no LUT in the GF(2⁴) inverse |
| DOM-masked tower-field S-box | The countermeasure: 2-share, registered DOM-AND gates, 4-cycle pipeline |
| Functional tests | Exhaustive 256-input check (unmasked) plus random sweep (DOM) |
| CPA / TVLA analyzers | Correlation power analysis and Welch fixed-vs-random t-test |

## 2. Attack model and constraints

No ChipWhisperer was available for this track, so "power" is a simulation-based
proxy: `HW(captured_result_register)`. The testbench runs in Vivado xsim;
analysis runs in Python (numpy/scipy/matplotlib). This is a standard fallback in
academic SCA work when hardware probes are not on hand.

The simulated power model captures the data-dependent switching power at the
captured register but does not include analog effects (glitches in unmasked
combinational paths, capacitive coupling, supply ringing). A "TVLA pass" in this
rig is necessary but not sufficient for hardware security; it is the correct
yardstick for an RTL-level demonstration of DOM principles.

## 3. Methodology

For both the unprotected baseline and the DOM-protected design:

- **CPA:** 20,000 random plaintext bytes XORed with a hidden key `0x2b`,
  Hamming-weight hypothesis `HW(sbox[pt ⊕ guess])`, Pearson correlation across
  all 256 guesses; Gaussian noise σ = 2.0 added so traces-to-disclosure is a
  meaningful curve rather than a single-trace break.
- **TVLA:** 40,000 traces, interleaved fixed-plaintext vs random-plaintext
  groups, Welch t-test on `HW(captured)`. Threshold |t| > 4.5 indicates
  first-order leakage.

The same analysis code runs against both rigs (identical CSV format), giving a
clean apples-to-apples before/after comparison.

## 4. Results

### 4.1 Baseline (unprotected Zkne S-box)

| Metric | Value |
|---|---|
| CPA recovered key byte | `0x2b` (rank 1/256) |
| Top-guess correlation \|r\| | 0.58 |
| Traces to disclosure | ~100 |
| TVLA Welch \|t\| | 44.0 (threshold 4.5) |
| Verdict | First-order leakage detected; key trivially recoverable |

### 4.2 DOM-protected S-box

| Metric | Value |
|---|---|
| CPA recovered key byte | `0x37` (random guess, not the true key) |
| True-key rank | 35 / 256 |
| Top-guess correlation \|r\| | 0.022 |
| Traces to disclosure | Not reached within 20,000 traces |
| TVLA Welch \|t\| | 1.41 (threshold 4.5) |
| Verdict | No first-order leakage detected; attack fails |

### 4.3 Before / after summary

| Metric | Unprotected | DOM | Improvement |
|---|---:|---:|---:|
| CPA true-key rank | 1 | 35 | 35x worse for attacker |
| CPA top-guess \|r\| | 0.58 | 0.022 | 26x smaller |
| TVLA \|t\| | 44.0 | 1.4 | 31x smaller |
| Above leakage threshold? | Yes | No | passes |

### 4.4 Area and timing cost (OOC synthesis, Vivado 2024.2, xc7z020clg400-1)

| Module | LUTs | FFs | Latency | WNS @ 100 MHz |
|---|---:|---:|---:|---:|
| `aes_sbox_tower` (unmasked) | 32 | 0 | combinational | n/a |
| `aes_sbox_tower_dom` | 182 | 100 | 4 cycles | +6.054 ns |
| DOM overhead | +150 (5.7x) | +100 | +3 cycles | positive |

Against the full-system baseline (10,171 LUTs / 8,522 FFs), integrating this DOM
S-box adds roughly +1.5% LUTs and +1.2% FFs. The WNS is solidly positive, so the
pipeline does not violate the 100 MHz constraint, leaving room for the
multi-cycle instruction to be folded into the ALU's existing ready/valid
handshake.

## 5. Architecture of the DOM-masked S-box

The AES S-box is `affine(x⁻¹ in GF(2⁸)) ⊕ 0x63`. The multiplicative inverse is
the only nonlinear step and is what masking has to protect. Pipeline:

1. **In-map** (linear GF(2) map): byte to tower representation under
   GF((2⁴)²)/`z²+z+λ`, λ = 0x8. Done per share.
2. **Tower inverse:** all nonlinearity lives in five GF(2⁴) multipliers, each
   registered as a DOM-AND gate.
   - Stage 1: `ah · al` (one DOM-multiply)
   - Stage 2: build `d = ah²·λ + ah·al + al²`, then `d²`, `d⁴`, `d⁸` (linear);
     DOM-multiply `m₁ = d² · d⁴`
   - Stage 3: DOM-multiply `m₂ = m₁ · d⁸` to get `d¹⁴ = d⁻¹`
   - Stage 4: parallel DOM-multiplies `ph = ah · d⁻¹`, `pl = (ah⊕al) · d⁻¹`
3. **Out-map** (linear): tower inverse to standard byte, folded with the AES
   affine's linear part; XOR with `0x63` on one share only.

Each DOM-AND gate computes `c = a · b` where `a = a₀⊕a₁`, `b = b₀⊕b₁`:

```
c₀ ← (a₀·b₀) ⊕ (a₀·b₁ ⊕ z)      registered at the same edge with
c₁ ← (a₁·b₁) ⊕ (a₁·b₀ ⊕ z)      the same fresh random nibble z
```

The register makes it glitch-resistant (no transient combination of both shares
can propagate forward) and `z` makes each share statistically independent of the
underlying secret. Five GF(2⁴) multipliers times 4 random bits is 20 bits of
fresh randomness per S-box execution.

The constants are derived and brute-force verified against all 256 entries of
the standard AES table before being put into RTL.

| Name | Value | Where |
|---|---|---|
| λ (GF(2⁴)) | `4'h8` | norm/inverse formula |
| θ (iso generator) | `8'h20` | used to derive the maps |
| `in_map` columns | `01 20 46 4c 3c d5 34 e5` | std-byte to tower |
| `out_map` columns | `1f b2 ab 36 52 3e 65 60` | tower-inverse to std-byte (then ⊕ 0x63) |

## 6. What this does and does not claim

- The simulation-based rig detects first-order leakage in the unprotected
  baseline (CPA recovers the key in ~100 traces; TVLA |t| = 44).
- The DOM-masked S-box defeats the same rig: CPA fails (true key never reaches
  rank 1; |r| = 0.022 vs 0.58); TVLA stays under 4.5.
- The DOM module is functionally equivalent to the unmasked one across all 256
  inputs and a random sweep of (input, mask, randomness) tuples.
- This is not a guarantee of hardware security. The simulation power model
  excludes glitches, coupling, and supply effects; a hardware-validated claim
  would need a CW305 board or formal verification with SILVER.
- The DOM module returns the result as two shares; full integration would require
  the software/ISA to track masks across instructions. Within this project the
  demonstration is at the unit level.

## 7. References

- Kassimi A., Aljuffri A., Larmann C., Hamdioui S., Taouil M., *Secure
  Implementation of RISC-V's Scalar Cryptography Extension Set*, Cryptography
  10(1):6, 2026.
- Gross H., Mangard S., Mendel F., *Domain-Oriented Masking: Compact Masked
  Hardware Implementations with Arbitrary Protection Order*, TIS 2016.
- Canright D., *A Very Compact S-Box for AES*, CHES 2005.
- FIPS PUB 197, *Advanced Encryption Standard*.
