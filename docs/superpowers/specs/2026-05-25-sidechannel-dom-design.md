# Side-Channel Track — Design Spec (Group 24, Daniel)

**Date:** 2026-05-25
**Owner:** Daniel Tyukov
**Branch:** `sidechannel-dom` (off `origin/adding-aes-rtl`, which carries Hruday's unprotected Zkne RTL)

## 1. Goal and north star

Prof. feedback (Ismail Bourhaiel, Teams, 2026-05-21): *"start by getting the
setup to measure the resilience to side-channel attacks to work … perform a
side-channel attack on the baseline and find correlation to the instruction
running. Once you have that, you should have a clear path to improve the
design and increase resilience."*

So the order of work is fixed:

1. **Measurement rig** that turns RTL simulation activity into power traces.
2. **Attack the baseline** (Hruday's unprotected `cv32e40p_zkne`) → recover the
   key, quantify leakage.
3. **Improve** — DOM-protected S-box RTL — and re-run the *same* rig to show
   leakage is gone.
4. **Document** the RTL and the methodology.

Daniel's assignment ("side-channel implementation RTL + documentation") is
steps 3–4, but step 1–2 is the harness that *proves* step 3, so it is built
first.

## 2. Locked decisions

| Fork | Decision | Why |
|---|---|---|
| Leakage source | **Simulation-based RTL leakage** (no ChipWhisperer) | Matches Kassimi et al. methodology and repo constraints; the only reproducible option without a probe. |
| Attack granularity | **Staged: unit-level first, then one full-core run** | Unit TB around `cv32e40p_zkne` iterates in seconds, is decoupled from teammates, and gives a clean unprotected-vs-DOM A/B. One system run honors "the instruction running." |
| Countermeasure | **Full DOM tower-field S-box** (GF((2⁴)²), 2 shares, registered DOM-AND + PRNG) | First-order secure; faithful to Prof. Taouil's paper. De-risked by building the *unmasked* tower-field S-box first. |
| Simulator | **Vivado xsim** (Verilator not installed on server) | Loop all traces inside one SV testbench → one xsim invocation per trace set. |
| Analysis | **Python on laptop** (numpy/scipy/matplotlib present; server base python lacks them) | Only the small CSV crosses the wire. |
| Power model | **Hamming weight of the captured result register** (default), Hamming distance logged too | HW(sbox[pt⊕k]) is the canonical CPA target; HD models synchronous toggle power for later realism. |

## 3. Attack model (why it is a real key recovery, not a toy)

The Zkne instruction computes `so = sbox[rs2_byte]`. In AES round 1 the byte fed
to the S-box is `rs2_byte = plaintext ⊕ key` (AddRoundKey already applied). The
testbench therefore:

- lets the **attacker control `pt`** (random plaintext byte),
- keeps **`k_secret` hidden** inside the TB,
- feeds `rs2_byte = pt ⊕ k_secret` into the DUT,
- logs a power proxy = `HW(result_register)` where `result = sbox[rs2_byte]`
  placed in lane `bs` (rs1/operand_a tied to 0 so the register equals the
  S-box output).

CPA then guesses `k`: for each guess `g`, the hypothesis is `HW(sbox[pt ⊕ g])`;
the guess whose hypothesis best correlates (Pearson) with the logged power is
the recovered key byte. This is a textbook first-round CPA — a genuine secret
recovery.

Realism: the TB logs **clean** HW; the Python adds configurable Gaussian noise
σ, so we can plot a *traces-to-disclosure* curve and a *correlation-vs-guess*
plot rather than a trivial single-trace break.

## 4. Components and interfaces

```
sidechannel/
├── tb/tb_zkne_leak.sv      # standalone unit TB; loops N traces; writes CSV
├── sim/run_leak_xsim.sh    # runs ON SERVER in ~/sca: xvlog→xelab→xsim
├── analysis/cpa.py         # CPA key recovery + plots (laptop)
├── analysis/tvla.py        # Welch fixed-vs-random t-test + plots (laptop)
└── out/                    # pulled CSVs + generated PNGs (gitignored heavy bits)
scripts/push-sca.sh         # scp TB + sim + the two DUT RTL files → server:~/sca/
```

**TB ⇄ analysis contract:** CSV columns `idx,group,pt,hw,hd`.
- `group`: 0 = random plaintext, 1 = fixed plaintext (TVLA only).
- `pt`: the attacker-known plaintext byte (0–255).
- `hw`: Hamming weight of the captured result register.
- `hd`: Hamming distance from the previous trace's result register.
- The secret key byte is **not** in the CSV (printed only to stdout for
  post-hoc verification).

**TB plusargs:** `+num_traces=`, `+seed=`, `+key_byte=`, `+tvla=0|1`,
`+fixed_pt=`, `+op=0|1` (0=aes32esi, 1=aes32esmi), `+bs=`, `+outfile=`.

**DUT under test:** `cv32e40p_zkne` (unprotected, Phase 1–2) → later
`cv32e40p_zkne_dom` (Phase 3+). Same TB, swap the instance.

## 5. Phases and milestones

- **P1 — rig:** TB + run script + cpa.py + tvla.py. Done when CPA recovers a
  known key byte from the unprotected module in simulation.
- **P2 — baseline attack:** recovered key + traces-to-disclosure + max |t|
  report on the unprotected module. *(This is the professor's named milestone —
  reportable to Ismail.)*
- **P3 — DOM RTL:** `aes_sbox_dom.sv` (GF((2⁴)²) inversion, 2 Boolean shares,
  registered DOM-AND, PRNG) + `cv32e40p_zkne_dom.sv`; 2-cycle, reuse the ALU
  `ready_o/ex_ready_i` handshake (coordinate with Hruday). De-risk: verify the
  *unmasked* tower-field S-box matches the 256-entry LUT first.
- **P4 — prove resilience:** rerun the rig on the DOM module → CPA fails, |t| <
  4.5; capture OOC area/timing cost vs the +5.513 ns slack and Kassimi's +0.39 %.
- **P5 — docs:** `SIDECHANNEL.md` (BASELINE.md-style) + inline RTL docs; feeds
  final report + slides.

## 6. Dependencies and risks

- **Independent of teammates** for P1–P4 unit-level (TB drives the module
  directly). Coordinate with Hruday on the 2-cycle handshake and the single
  system-level confirmation run (needs his C inline-asm `aes32esmi` path).
- **DOM S-box is hard RTL** → split into unmasked-tower-field (must match LUT)
  then add masking.
- **TVLA may not fully close under glitches** → registered DOM gates target
  exactly this; if residual leakage remains, document honestly — the professor
  asked for *measured improvement*, not perfection.
- **2-cycle latency** interacts with Hruday's single-cycle assumption →
  coordinate early.

## 7. Server facts (verified 2026-05-25)

- Host `ce-procdesign01`, user `cese4040-24`, 125 GB RAM (112 free).
- Vivado 2024.2 `xvlog/xelab/xsim` present; **Verilator absent**.
- Server `~/pdp-project` is on `main` @ `2ea6de7` (pre-Hruday) — the zkne module
  is **not** on the server. Unit sim copies the 2 RTL files into `~/sca/` so it
  does not depend on the server repo or the Vivado project.
- Laptop has numpy 1.26.4 / scipy 1.11.4 / matplotlib 3.6.3.
