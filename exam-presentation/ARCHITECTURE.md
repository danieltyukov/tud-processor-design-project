# Slide-by-slide map + technical internals — PDP Group 24

Deck: `PDP_group24_Final.pdf`, **29 slides**, dated 18-6-2026. Use the slide
numbers below to answer "what's on slide N?" or "explain slide N." Numbers are
quoted exactly as they appear on the slide.

## Slide-by-slide (1–29)

- **Slide 1 — Title.** "Processor Design Project", Group 24. TU Delft. Image is a
  Benes/butterfly permutation network (decorative).
- **Slide 2 — Introduction.** Data security is critical across embedded systems,
  IoT, and communications. Encryption is the primary mechanism; AES is the global
  standard. **Goal: implement AES acceleration on a RISC-V core efficiently in
  hardware.**
- **Slide 3 — Where is AES used?** HTTPS/TLS, Wi-Fi (WPA2/WPA3), file encryption,
  cloud storage, VPNs, USB drives & SSDs, smart cards & passports, IoT devices.
  IoT is the motivating case: same crypto, almost no power/area budget.
- **Slide 4 — AES (what).** Symmetric block cipher (same key enc/dec). Operates
  on a **4×4 matrix of bytes = the "state" (128 bits)**. Key expanded into **11
  round keys** via the key schedule. Right: full AES encrypt/decrypt structure.
- **Slide 5 — AES (how).** Initial round = plaintext XOR round key 0. **9 middle
  rounds**, each: **SubBytes** (S-box, confusion), **ShiftRows** (cyclic row
  shifts, spreads across columns), **MixColumns** (column mixing over GF(2⁸),
  diffusion), **AddRoundKey** (XOR round key). **Final round (10): same but NO
  MixColumns.** "The whole project is about collapsing those four steps."
- **Slide 6 — Baseline software implementation.** Pure C AES-128 on the
  unmodified RISCY core; table-based S-box + `gf_mult` MixColumns, all from data
  memory, no HW acceleration. Table: **Cycle Count 61,184 · LUTs 4,644 ·
  Registers 2,163 · Muxes 284.** This is the bottleneck the hardware targets.
- **Slide 7 — Baseline bottlenecks.** Bar chart "where the software AES spends
  its cycles": **mix_columns 83.8% (50,643 cyc)**, add_round_key 4.7% (2,850),
  sub_bytes 4.4% (2,679), expand_key 4.0% (2,417), shift_rows 0.8% (510).
  Conclusion: MixColumns is the only thing worth accelerating.
- **Slide 8 — How does hardware help?** The ~**186-instruction** software
  `mix_columns` collapses to a few `aes32esmi` calls (no `gf_mult`). Runs
  entirely on registers — no BRAM loads for S-box or MixColumns. **`aes32esmi` =
  SubBytes + ShiftRows + MixColumns + AddRoundKey, one byte per cycle.**
- **Slide 9 — Performance after AES hardware support.** Table: Software baseline
  **61,184** (1.0×) → **+ aes32esmi/aes32esi = 6,260 cycles (9.8× faster)**.
  6,260 is the starting point for the next two optimisations (→ 4,800 → 4,104).
- **Slide 10 — Optimization Overview.** The whole arc on one slide:
  **61,184 → 6,260 (9.8×) → 4,800 (−23%) → 4,104 (−34%)**, tagged
  "≈15× faster" and "side-channel hardened." Three cards: (1) Hardware AES
  instructions (Zkne); (2) Custom LLVM loop-unroll pass; (3) Parallel DOM S-box
  (RTL): "CPA 0.24 → 0.07, TVLA |t| 49 → 4.0 (below threshold)."
- **Slide 11 — Vulnerabilities to side-channel attacks.** The Zkne S-box and
  MixColumns switch a data-dependent number of bits → power leaks the byte. **CPA
  recovers a key byte in ~100 traces** on the unprotected core. **Countermeasure:
  Domain-Oriented Masking (DOM)** — split secrets into two random shares,
  recombine only inside registered gates, so no wire/glitch tracks the real
  value. Follows the TU Delft secure-Zkne paper (Kassimi, Aljuffri, Hamdioui,
  Taouil, 2026). Pipeline figure: power trace → correlate vs HW(SBOX[pt⊕k]) →
  256 key guesses → key byte.
- **Slide 12 — Compiler: custom LoopUnroll pass (what).** Wrote our own LLVM pass
  to fully unroll the 9-round AES loop; calls LLVM's unroll routine directly
  (not a built-in flag); flattens all 9 rounds into straight-line code; **detects
  the loop by spotting the AES instructions inside it, so it survives inlining.**
- **Slide 13 — Compiler: custom LoopUnroll pass (why).** Looped version wastes
  cycles on per-round overhead (counter, branch, condition check, key-pointer
  reload). Built-in unrolling is cost-model driven and often refuses (especially
  `-Os`). Wanted full control to force unroll on exactly the target loop; goal
  was to build the optimisation ourselves.
- **Slide 14 — Compiler: results.** Table: GCC -Os looped (none) **6260** (−);
  GCC -Os + `#pragma unroll` (source pragma) **6067 (−3%)**; GCC -O2 +
  `-funroll-loops` (built-in flag) **5509 (−12%)**; **Clang -Os + custom pass
  (AESUnroll) 4800 (−23%)**. Same correct ciphertext; loop always fully unrolled.
- **Slide 15 — Secure AES implementation (instruction + shares).** Original:
  `aes32esmi rd, rs1, rs2, bs`. Under the secure (DOM) implementation each
  operand is split: `share0_rs1 = rs1 ⊕ fresh_random`, `share1_rs1 =
  fresh_random`, `share0_rs2 = rs2 ⊕ fresh_random`, `share1_rs2 = fresh_random`.
  Datapath diagram: two shares → **Shared Forward/Inverse S-box → Shared
  MixColumns/InvMix → Optimized Byte Rotation**, recombined into `rd`. Cite:
  Kassimi et al., *Cryptography* 10(1):6, Jan 2026, doi:10.3390/cryptography10010006.
- **Slide 16 — Secure AES implementation (S-box internals).** The masked S-box as
  Top-linear-layer (8→21-bit `t1`) → **Shared Non-linear Middle layer** (→18-bit
  `t2`) → Bottom-linear-layer (→8-bit) → `sbox_fwd_out / sbox_inv_out`. `dec`
  selects forward/inverse. Only the middle (non-linear) layer needs masking.
- **Slide 17 — RTL Optimization: Parallel DOM S-box (what).** Custom instruction
  runs **two DOM-protected S-boxes in parallel**; each instruction processes
  **two byte-lanes of a column** instead of one. New EX unit (two S-boxes side by
  side) + decoder & pipeline changes. Software XORs the two halves to finish each
  column. Kept the original single-S-box path as a fallback. (BEFORE: 1 S-box, 1
  lane → AFTER: 2 S-boxes, 2 lanes → XOR.)
- **Slide 18 — Parallel DOM S-box (why).** The DOM S-box is the real bottleneck:
  every byte pays a fixed **5-cycle latency** and stalls the whole pipeline. The
  original did one byte at a time → 16 bytes/round fully serial (**16 × 5-cycle
  ops**). Two lanes at once → **8 × 5-cycle ops (half the steps)**. Masking (DOM)
  stays fully intact.
- **Slide 19 — Parallel DOM S-box (results).** Stage table: Original **6260**
  (baseline) → Custom Unroll Pass **4800 (23% faster)** → Parallel DOM S-box
  **4104 (34% faster)**. Resource table for the parallel-DOM core: **Cycle Count
  4,121 · LUTs 11,987 · Registers 10,412 · Muxes 289 · DSP 5.** (Area is the cost
  of two masked S-boxes + a wider datapath.)
- **Slide 20 — Validation framework: simulation-based power analysis.** Pipeline:
  **RTL S-box (unprotected/DOM) → xsim testbench logs HW(power) → CSV (pt, power)
  → CPA/TVLA (Python) → leakage verdict.** Power proxy = **Hamming weight of the
  captured S-box result**, logged per trace by a SystemVerilog testbench in
  Vivado xsim; the same rig drives both designs (clean before/after). CPA:
  correlate power with HW(SBOX[pt⊕guess]) over all 256 guesses, **20,000 traces**.
  TVLA: Welch fixed-vs-random t-test, **40,000 traces**; |t| > 4.5 = first-order
  leakage. Alongside Rishi's CW305 hardware validation.
- **Slide 21 — Validation results: DOM defeats the attack (simulation).** Same
  rig, noise **σ = 2.0**, only the S-box changes. TVLA (left): unprotected Zkne
  **|t| → 44**, DOM-masked **|t| = 1.4**, threshold 4.5. CPA (right, 20,000
  traces): unprotected **rank 1/256, |r| = 0.584** (true key 0x2b); DOM-masked
  **rank 35/256, |r| = 0.010**. Table: CPA true-key rank 1/256 → 35/256; CPA top
  |r| 0.58 → 0.022; TVLA max |t| 44.0 → 1.4; crosses |t|=4.5? Yes → No.
- **Slide 22 — Hardware validation: CW305 setup.** CW305 Artix-7 100T with
  **CV32E40P** soft-core. ChipWhisperer-Lite scope, **50 MHz clock, ADC 200 MHz,
  gain 30 dB**. Three bitstreams: **AES_100t (reference), Baseline RI5CY,
  DOM-protected RI5CY**. Attack: CPA `sbox_output` and `last_round_state_diff`
  leakage models; window samples 0–80 (round-1 S-box); TVLA Welch fixed-vs-random
  PT; threshold |t| > 4.5.
- **Slide 23 — Hardware validation results (table).** AES_100t: CPA **16/16**
  recovered, max corr **0.236** (strong), TVLA **|t| 49.27** (10.9× threshold),
  leakage Yes. Baseline RI5CY: **0/16** (need more traces), corr 0.21 PGE
  dropping, TVLA **4.69** (marginal, 1 sample). DOM-protected RISCY: **0/16
  (protected)**, corr **0.07** (noise floor), TVLA **3.98** (below threshold), no
  leakage. Finding: CPA breaks unprotected HW AES (corr 0.236); DOM → 0.07 corr
  and TVLA below threshold → first-order SC resistance confirmed on real hardware.
- **Slide 24 — Hardware validation results (TVLA plots).** Three traces vs the
  |t|=4.5 dashed threshold (ISO/IEC 17825): **AES_100t spikes to 49.27** (10×
  above, strong leakage); **Baseline RISCY 4.69** (barely crosses, 1 leaking
  sample of 2000); **DOM-protected 3.98** (below throughout, zero leaking
  samples). Conclusion: DOM eliminates first-order leakage on real silicon,
  consistent with simulation.
- **Slide 25 — Future Work (the observation).** AES does the **same op 4×** per
  round: `aes32esmi t0,t0,a4,0` / `a5,1` / `a6,2` / `a7,3`. 4 instructions per
  round (a consequence of the 32-bit register width) → extra fetch/decode,
  higher instruction count, a throughput ceiling. Independent, highly regular.
- **Slide 26 — The Super Instruction (idea).** Introduce one fused "super
  instruction": replicate the AES32/Zkne datapath **4×**, execute in parallel
  within a single instruction, combine internally (XOR) and write back the final
  32-bit result. Block diagram: ZKNE MODULE 1–4 → XOR.
- **Slide 27 — Super Instruction (architectural changes).** (i) New opcodes &
  instruction format: `RS4 | RS3 | RS2 | RS1 | … | S | opcode`; (ii) register
  file / decode-logic changes (4 source registers); (iii) replicate the Zkne
  hardware; (iv) software support for the instruction.
- **Slide 28 — Super Instruction (limitations).** Opcode-space pollution
  (custom-0 opcodes clash with future standard extensions); register-file
  pressure (4 source reads → extra ports or a 2-cycle read); higher hardware
  utilisation (4× datapath = more LUTs/FFs); narrow workload applicability (only
  AES; idle otherwise). **Not built — future work; does not yet produce correct
  ciphertext, so the shipping core uses the 2-lane parallel DOM S-box.**
- **Slide 29 — Thank you.**

## DOM-masked S-box internals (for deep questions)
AES S-box = `affine(x⁻¹ in GF(2⁸)) ⊕ 0x63`. The multiplicative **inverse is the
only nonlinear step**, so that is all masking must protect. We use a **tower-field**
construction GF((2⁴)²) over `z²+z+λ`, λ = `4'h8` (Canright-style), and a 2-share
DOM pipeline (~4 cycles in the unit; ~5-cycle effective latency per byte once
pipelined into the core):
1. **In-map** (linear): byte → tower representation, per share.
2. **Tower inverse** — nonlinearity in **five GF(2⁴) multipliers**, each a
   registered **DOM-AND** gate: build `d` and its powers (linear), then
   `m₁ = d²·d⁴`, `m₂ = m₁·d⁸ = d⁻¹`, then `ph = ah·d⁻¹`, `pl = (ah⊕al)·d⁻¹`.
3. **Out-map** (linear): tower-inverse → standard byte, XOR `0x63` on one share.

Each DOM-AND computes `c = a·b` with `a = a₀⊕a₁`, `b = b₀⊕b₁`:
`c₀ ← a₀·b₀ ⊕ (a₀·b₁ ⊕ z)`, `c₁ ← a₁·b₁ ⊕ (a₁·b₀ ⊕ z)`, **registered at the same
edge with the same fresh random nibble z**. The register stops glitches
propagating both shares; `z` makes each share independent of the secret.
**5 multipliers × 4 random bits = 20 bits of fresh randomness per S-box.**
Constants (λ=`4'h8`, θ=`8'h20`, in_map/out_map columns) were derived and
brute-force verified against all 256 standard S-box entries before going to RTL.

## CPA vs TVLA (the two analyses)
- **CPA (Correlation Power Analysis):** guess one key byte, predict leakage as
  `HW(Sbox[pt ⊕ guess])`, take Pearson correlation against measured power over all
  256 guesses; the correct guess spikes. Metric: **true-key rank / PGE** (rank
  among 256; 0/rank-1 = recovered) and top |r|.
- **TVLA (Test Vector Leakage Assessment):** Welch's t-test between **fixed-** and
  **random-plaintext** trace groups. **|t| > 4.5 ⇒ first-order leakage.** Doesn't
  recover a key — just detects data-dependence. Threshold is ISO/IEC 17825 /
  NIST SP 800-140C.

## Simulation vs hardware (numbers can differ — know which is which)
| | Simulation (xsim + Python) | Hardware (CW305) |
|---|---|---|
| Unprotected TVLA max \|t\| | 44 (Zkne S-box) | 49.27 (AES_100t ref) / 4.69 (baseline RI5CY) |
| DOM TVLA max \|t\| | 1.4 | 3.98 |
| CPA unprotected | rank 1/256, \|r\|=0.58 | AES_100t 16/16, corr 0.236 |
| CPA DOM | rank 35/256, \|r\|=0.022 | 0/16, corr 0.07 (noise floor) |
| Full key recovery on *our* core? | demonstrated in sim | **no** (only on AES_100t ref) |

The clean, reproducible before/after is the **simulation**. The CW305 setup is
validated by full key recovery on the **AES_100t reference**; on our own cores it
shows measurable leakage (PGE drops) but did not fully recover the key in the lab
time. DOM pushes TVLA below threshold in both. Trigger placement mattered: moving
the capture trigger to **after** software key-expansion improved trace variance
**~40×**.

## Repo / artifact map (`pdp-project-24/`)
- `software/main.c` — AES-128 C source (round loop kept as a plain loop).
- `software/main_cw_dom.c`, `main_cw_dom_fixed.c` — CW305 firmware (DOM, AHB2CW
  peripheral at `0x51000000`: wait CW_START → read key/pt → trigger → AES → write
  ciphertext → CW_DONE).
- `compiler/aes-unroll-pass/AESUnroll.cpp` — the LLVM loop pass
  (`PassInfoMixin`, `-fpass-plugin=libAESUnroll.so`).
- `hardware/src/design/riscy/cv32e40p_zkne.sv` — Zkne hardware AES.
- `…/cv32e40p_zkne_dom.sv`, `aes_sbox_dom.sv`, `aes_sbox_canright_pkg.sv` —
  single-lane DOM S-box.
- `…/cv32e40p_zkne_dom2.sv` — **the parallel 2-lane DOM S-box (shipping core).**
- `hardware/src/simulation/zynq_tb.sv` — testbench (`mem_snoop_match` watches
  `0xDEADBEEF` at `0x2000`).
- `sca_results/` — TVLA/CPA traces (`.npy`), comparison plots,
  `SCA_METHODOLOGY.md` (CW305) and `SCA_README.md`.
- `docs/BASELINE.md`, `docs/PROFILING.md`, `docs/SIDECHANNEL.md` — measured
  baseline, profiling, and the simulation side-channel track.
- `future-work/super-instruction/` — the 4-wide fused-op snapshot (NOT built;
  doesn't yet produce correct ciphertext).

## Glossary
- **Zkne** — RISC-V scalar-crypto AES *encryption* extension. `aes32esmi` =
  middle-round (Sub+Shift+Mix+AddKey); `aes32esi` = final round (no MixColumns).
- **CV32E40P / RI5CY / "RISCY"** — the 32-bit RISC-V core we modified.
- **DOM** — Domain-Oriented Masking: 2-share masking with registered AND gates +
  fresh randomness; resists first-order power analysis and glitches.
- **GF(2⁸) / tower field** — AES finite field; tower form GF((2⁴)²) makes the
  S-box inverse cheap and maskable.
- **PGE** — Partial Guessing Entropy = rank of the correct key byte (0 = broken).
- **OOC synthesis** — Out-of-Context: synthesise the core alone for quick
  area/timing estimates.
