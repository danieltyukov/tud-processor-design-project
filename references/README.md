# Reference papers

Papers we cite or draw inspiration from for the intermediate report and Phase 2.

## `kassimi-2026-secure-zkne-dom.pdf`

**Kassimi A., Aljuffri A., Larmann C., Hamdioui S., Taouil M.** —
*"Secure Implementation of RISC-V's Scalar Cryptography Extension Set"* —
Cryptography (MDPI), Vol. 10 No. 1 Article 6, 17 January 2026.
DOI: [10.3390/cryptography10010006](https://doi.org/10.3390/cryptography10010006)

Authors are from **TU Delft Department of Computer Engineering** (same
department teaching CESE4040). Senior author **Mottaqiallah Taouil** is
the "Prof. Mottah" Vishnu has emailed for guidance.

### What it does

Adds **Domain-Oriented Masking (DOM)** to the AES instructions of the
Zkne/Zknd extensions to resist **first-order power side-channel
attacks** (DPA / CPA / TPA). Key contributions:

1. Optimized unmasked AES module (shared SBox logic for enc/dec).
2. DOM-protected AES module against first-order PSCAs.
3. Assembly-level optimizations (partial-round + key-scheduling) so
   the protected version runs at zero perf overhead with proper
   instruction scheduling.
4. Empirical security validation via **TVLA, SNR, CPA, TPA, key-rank
   analysis**.
5. Area + power overhead comparison vs. SoTA.

### Reported results (theirs)

| Metric | Value |
|---|---|
| Target FPGA | Xilinx Artix-7 |
| Target core | **CV32E40S** (note: different from our CV32E40P) |
| Area overhead | **+0.39 %** of full 32-bit core |
| Performance overhead | **0 %** with proper scheduling |
| Side-channel resistance | First-order resistant (TVLA, CPA-validated) |

### Relevance to us / caveats

- **Same Zkne semantics** as our project — directly applicable.
- **Different core variant** — they used CV32E40S (S-profile), we use
  CV32E40P (P-profile). Both OpenHW Group 32-bit in-order, but
  different pipeline depth and ISA configuration. Their integration
  details may not port verbatim.
- They had access to **ChipWhisperer** for empirical power traces —
  per Vishnu's chat we don't, so our validation has to fall back to
  Hamming-distance models extracted from `.vcd` (or Vivado `.saif`).
- Tools mentioned: **SILVER** (formal SCA verification) — open-source.

### How we use it in the report

- Section "State of the art / background" — primary citation for the
  side-channel improvement option (Q3 motivation).
- Methodology — borrow their TVLA + CPA + key-rank framework.

## `pan-2021-aes-coprocessor.pdf`

**Pan L., Tu G., Liu S., Cai Z., Xiong X.** —
*"A Lightweight AES Coprocessor Based on RISC-V Custom Instructions"* —
Security and Communication Networks (Wiley/Hindawi), Vol. 2021 Article 9355123, 30 December 2021.
DOI: [10.1155/2021/9355123](https://doi.org/10.1155/2021/9355123)

Authors are from **Wuhan University**, China.

### What it does

Builds an **AES coprocessor accessed via RISC-V custom instructions**
on the **Hummingbird E203** open-source RISC-V core. Two features
that drive their performance:

1. **Custom instruction extension** under the `custom-0` opcode — one
   instruction triggers a full AES-CBC or AES-CMAC operation rather
   than a per-round software loop.
2. **DMA channel** giving the coprocessor direct memory access to the
   input data buffer in parallel with CPU execution.

### Reported results (theirs)

| Metric | Value |
|---|---|
| Target core | **Hummingbird E203** (Nuclei Tech, not CV32E40P) |
| Target FPGA | Generic SoC FPGA (paper does not specify part) |
| Runtime gain (input ≥ 80 bytes) | **25.3 %–37.9 %** vs. similar prior work |
| ASIC power overhead | up to +20 % vs. baseline AES ops |

### Relevance to us / caveats

- **Different core** — Hummingbird E203 has a 2-stage pipeline; CV32E40P
  has 4 stages. ALU integration looks different.
- **Their full design (coprocessor + DMA + CBC orchestration) is
  bigger than what fits in our 8-week budget.** What we adapt is the
  *kernel idea*: collapse the 4-instruction `aes32esmi` chain that
  computes one column-word into a **single fused instruction**. This
  is Hruday's "super-instruction".
- Their >25 % win is end-to-end (multi-block CBC) — our adapted
  single-fused-instruction will have a smaller win, but is realistic
  in the time we have.

### How we use it in the report

- Section "State of the art / background" — primary citation for the
  super-instruction (Q3 motivation, Q1 Option 2 description).
- Methodology — comparison anchor: cycle count of baseline vs.
  `aes32esmi`-only vs. fused-super-instruction.
