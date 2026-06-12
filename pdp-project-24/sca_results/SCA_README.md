# Side-Channel Analysis (CV32E40P RISC-V on CW305)

Side-channel analysis experiments performed on the CW305 Artix-7 FPGA with a
CV32E40P RISC-V soft-core running AES-128, plus a NewAE hardware-AES reference.
The goal is to assess whether DOM (Domain-Oriented Masking) protects the Zkne
AES hardware extension against power analysis.

## Hardware Setup

- **Target board:** CW305 (Artix-7 XC7A100T FPGA)
- **Scope:** ChipWhisperer-Lite, ADC at 200 MHz (extclk_x4)
- **Measurement point:** SMA cable to X4 (low-noise shunt)
- **Clock:** 50 MHz for RISCY designs, 10 MHz for the AES_100t reference

## Designs Under Test

| Bitstream | Description |
|---|---|
| AES_100t | NewAE reference hardware AES (measurement validation) |
| Baseline RISCY | CV32E40P plus software AES in C (no protection) |
| Zkne unprotected | CV32E40P plus Zkne hardware AES (no DOM masking) |
| DOM protected | CV32E40P plus Zkne with DOM masking |

## Experimental Results

### TVLA (Test Vector Leakage Assessment)

TVLA uses Welch's t-test between fixed and random plaintext power traces. A
|t-value| > 4.5 indicates statistically significant leakage.

| Design | Max \|t-value\| | Leaking samples | Result |
|---|---:|---:|---|
| AES_100t (NewAE HW AES) | 49.27 | 47 | Strong leakage |
| Baseline RISCY (SW AES) | 4.69 | 1 | Marginal leakage |
| DOM Protected RISCY | 3.98 | 0 | Below threshold |

### CPA (Correlation Power Analysis)

CPA attempts to recover the AES key by correlating power traces with a leakage
model prediction.

| Design | Bytes recovered | Max correlation | Notes |
|---|---:|---:|---|
| AES_100t | 16/16 | 0.236 | Full key recovered; setup validated |
| Baseline RISCY (SW AES) | 0/16 | 0.127 | PGE reached 5; leakage present |
| Zkne unprotected | 0/16 | 0.070 | PGE reached 1 to 3; leakage present |
| DOM protected | 0/16 | 0.072 | At noise floor; attack fails |

## Interpretation (Important Caveat)

The strong, fully-recoverable leakage (TVLA 49.27, key 16/16 recovered) is on the
**AES_100t dedicated-hardware reference design, not our RISC-V core.** Its only
role here is to validate the measurement setup: a successful full key recovery on
a known-leaky reference confirms the capture chain works.

On **our own design** the picture is different. Baseline RISCY leakage is
marginal (TVLA 4.69, just above threshold), and full key recovery was not
achieved within the available trace count on any RISCY variant. DOM masking
brings the maximum t-value below the 4.5 threshold (3.98) and holds CPA
correlation at the noise floor (~0.07, identical to random guessing). We do not
claim the key was recovered on our own design.

## Key Findings

1. **DOM masking reduces leakage below threshold:** TVLA t-value 4.69 (baseline
   RISCY) to 3.98 (DOM), with CPA correlation at the noise floor (0.07).
2. **Trigger placement is critical:** moving the capture trigger to after
   `expand_key()` removed software key-expansion noise from the window and
   increased trace variance roughly 40x.
3. **Hardware AES leaks more than software AES:** the AES_100t S-box executes in
   one clock cycle, producing a clean leakage spike (t = 49.27), whereas software
   AES on RISCY spreads computation across hundreds of cycles and dilutes the
   signal (t = 4.69).
4. **Clipping must be filtered:** Zkne hardware instructions cause large power
   spikes; about 45% of captures clip the ADC above 10 dB gain and are discarded.

## How CPA Works

CPA recovers secret key bytes from power measurements:

1. **Capture:** record power during N AES encryptions with random plaintexts and
   a fixed key.
2. **Hypothesis:** for each of 256 key-byte guesses `k`, compute a predicted
   power value from a leakage model, typically `HW(Sbox[plaintext_byte XOR k])`.
3. **Correlate:** compute Pearson correlation between hypothesis and actual power
   at every sample. The correct guess spikes; wrong guesses stay near zero.
4. **Rank:** the highest-correlation guess is the recovered byte. Repeat for all
   16 bytes. PGE (Partial Guessing Entropy) is the rank of the correct byte;
   PGE = 0 means recovered.

## How TVLA Works

TVLA asks whether power consumption depends on the data being processed:

1. Capture one group with a fixed plaintext and one with random plaintexts.
2. At each sample, run a Welch's t-test between the two groups.
3. If |t-value| > 4.5, power at that sample depends on the data: leakage
   detected. TVLA does not recover the key; it only confirms whether leakage
   exists.

## Reproducing the Experiments

Requirements: `chipwhisperer >= 6.0`, `numpy`, `scipy`, `matplotlib`.

1. Connect the CW305 and ChipWhisperer-Lite as described in Hardware Setup.
2. Open `notebooks/sca_final_experiments.ipynb` in Jupyter.
3. Update the bitstream paths to match your machine.
4. Run cells sequentially.

The `traces/zkne_clean/` folder contains 15,000 power traces captured from the
unprotected Zkne design; these can be loaded and attacked without hardware by
running the analysis cells after loading the saved project.
