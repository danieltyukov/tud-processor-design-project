# Side-Channel Analysis — CV32E40P RISC-V on CW305
**TU Delft CESE4040 PDP Project**

## Overview

This folder contains the complete side-channel analysis experiments performed on the CW305 Artix-7 FPGA with a CV32E40P RISC-V soft-core processor implementing AES-128 encryption.

The goal is to validate that DOM (Domain-Oriented Masking) successfully protects the Zkne AES hardware extension against power analysis attacks.

---

## Hardware Setup

- **Target board:** CW305 (Artix-7 XC7A100T FPGA)
- **Scope:** ChipWhisperer-Lite
- **Measurement point:** SMA cable connected to X4 (low-noise shunt)
- **20-pin ribbon cable** between CW305 and ChipWhisperer-Lite
- **Clock:** 50MHz for RISCY designs, 10MHz for AES_100t reference
- **ADC:** extclk_x4 (200MHz sample rate)

---

## Folder Structure

```
sca_results/
├── bitstreams/
│   ├── baseline_cw305_top.bit       ← Vanilla RISCY + software AES (no protection)
│   ├── dom_cw305_top.bit            ← CV32E40P + DOM-masked Zkne
│   ├── zkne_fixed_cw305_top.bit     ← Unprotected Zkne (fixed trigger placement)
│   └── zkne_unprotected_cw305_top.bit ← Unprotected Zkne (original)
├── traces/
│   ├── zkne_clean/                  ← 15000 clean non-clipping traces (Zkne unprotected)
│   │   └── (ChipWhisperer project files)
│   ├── tvla_aes100t_fixed.npy       ← Fixed plaintext traces, AES_100t
│   ├── tvla_aes100t_random.npy      ← Random plaintext traces, AES_100t
│   ├── tvla_baseline_fixed.npy      ← Fixed plaintext traces, baseline RISCY
│   ├── tvla_baseline_random.npy     ← Random plaintext traces, baseline RISCY
│   ├── tvla_dom_fixed.npy           ← Fixed plaintext traces, DOM protected
│   └── tvla_dom_random.npy          ← Random plaintext traces, DOM protected
├── plots/
│   ├── tvla_aes100t.png             ← TVLA result for AES_100t
│   ├── tvla_baseline.png            ← TVLA result for baseline RISCY
│   ├── tvla_dom.png                 ← TVLA result for DOM protected
│   ├── tvla_comparison.png          ← Three-panel TVLA comparison
│   └── final_summary.png            ← CPA + TVLA summary bar charts
├── notebooks/
│   └── sca_final_experiments.ipynb  ← Complete reproducible experiment notebook
└── README.md                        ← This file
```

---

## Experimental Results

### TVLA (Test Vector Leakage Assessment)

TVLA uses Welch's t-test between fixed and random plaintext power traces. A |t-value| > 4.5 indicates statistically significant leakage.

| Design | Max \|t-value\| | Leaking samples | Result |
|--------|----------------|-----------------|--------|
| AES_100t (NewAE HW AES) | **49.27** | 47 | ⚠️ STRONGLY LEAKS |
| Baseline RISCY (SW AES) | **4.69** | 1 | ⚠️ MARGINAL LEAKAGE |
| DOM Protected RISCY | **3.98** | 0 | ✅ PROTECTED |

### CPA (Correlation Power Analysis)

CPA attempts to recover the secret AES key by correlating power traces with a leakage model prediction.

| Design | Bytes Recovered | Max Correlation | Notes |
|--------|----------------|-----------------|-------|
| AES_100t | **16/16** | 0.236 | Full key recovered — setup validated |
| Baseline RISCY (SW AES) | 0/16 | 0.127 | PGE reached 5 — leakage present |
| Zkne Unprotected | 0/16 | 0.070 | PGE reached 1-3 — leakage confirmed |
| DOM Protected | **0/16** | 0.072 | CPA fails — masking defeats attack |

---

## Saved Traces — Try It Yourself

The `traces/zkne_clean/` folder contains **15,000 power traces** captured from the unprotected Zkne design. These can be loaded and attacked without needing the hardware.

### Loading and attacking the saved traces

```python
import chipwhisperer as cw
import chipwhisperer.analyzer as cwa
import numpy as np

# Load saved traces
proj = cw.open_project('sca_results/traces/zkne_clean')
print(f'Loaded: {len(proj.traces)} traces')

KEY = [0x2b,0x7e,0x15,0x16,0x28,0xae,0xd2,0xa6,
       0xab,0xf7,0x15,0x88,0x09,0xcf,0x4f,0x3c]

# Try CPA with sbox_output model
attack = cwa.cpa(proj, cwa.leakage_models.sbox_output)
results = attack.run()

recovered = [kguess[0][0] for kguess in results.find_maximums()]
max_corr  = max(kguess[0][2] for kguess in results.find_maximums())
correct   = sum(r==k for r,k in zip(recovered, KEY))
print(f'Bytes correct: {correct}/16  Max corr: {max_corr:.4f}')
print(f'Recovered: {" ".join(f"{b:02x}" for b in recovered)}')
```

### Things to try

1. **Different leakage models:**
   ```python
   cwa.leakage_models.sbox_output          # First round S-Box output (HW)
   cwa.leakage_models.last_round_state_diff # Last round Hamming Distance
   ```

2. **Focus on different sample windows** (variance peak is around sample 18-71):
   ```python
   # Trim traces to focus window
   proj_focused = cw.create_project('focused', overwrite=True)
   for t in proj.traces:
       proj_focused.traces.append(cw.Trace(t.wave[0:50], t.textin, t.textout, t.key))
   ```

3. **Track PGE evolution** as you add more traces:
   ```python
   for n in [1000, 2000, 5000, 10000, 15000]:
       proj_n = cw.create_project(f'proj_{n}', overwrite=True)
       for t in proj.traces[:n]:
           proj_n.traces.append(t)
       attack = cwa.cpa(proj_n, cwa.leakage_models.sbox_output)
       results = attack.run()
       pge = results.find_maximums()[0][0][1]
       corr = results.find_maximums()[0][0][2]
       print(f'n={n}: PGE={pge} corr={corr:.4f}')
   ```

4. **Custom leakage model** — implement your own model targeting the Zkne MixColumns output

---

## How CPA Works

CPA (Correlation Power Analysis) is a statistical attack that recovers secret key bytes from power measurements.

**Step 1 — Capture traces:** Record power consumption during N AES encryptions with different random plaintexts but the same fixed key.

**Step 2 — Build hypothesis:** For each of 256 possible key byte guesses `k`, compute a predicted power value using a leakage model. The standard model is Hamming Weight of the S-Box output: `HW(Sbox[plaintext_byte XOR k_guess])`

**Step 3 — Correlate:** Compute Pearson correlation between the hypothesis and actual power at every sample point. The correct key guess produces a correlation spike; wrong guesses stay near zero.

**Step 4 — Rank:** The key guess with highest maximum correlation is the recovered key byte. Repeat for all 16 bytes.

**PGE (Partial Guessing Entropy):** The rank of the correct key byte among all 256 guesses. PGE=0 means the correct key is ranked #1 — attack succeeded.

---

## How TVLA Works

TVLA (Test Vector Leakage Assessment) asks: does this device's power consumption depend on the data it's processing?

**Step 1:** Capture two groups of traces — one with a fixed plaintext (always the same) and one with random plaintexts.

**Step 2:** At each sample point, run a Welch's t-test between the two groups.

**Step 3:** If |t-value| > 4.5, the power at that sample is statistically different between groups — meaning it depends on the data — leakage detected.

TVLA does not recover the key. It only confirms whether leakage exists.

---

## Key Findings

1. **DOM masking works** — CPA correlation stays at noise floor (0.07) for DOM design, identical to random noise. TVLA t-value drops from 49.27 (AES_100t) to 3.98 (DOM), below the 4.5 threshold.

2. **Trigger placement is critical** — originally the trigger fired before key expansion, filling the capture window with software noise. Moving the trigger to after `expand_key()` dramatically improved signal quality (variance increased 40×).

3. **Hardware AES leaks more than software AES** — AES_100t (dedicated hardware) has t=49.27 while software AES on RISCY has t=4.69. Hardware S-Box executes in one clock cycle giving a clean leakage spike; software AES spreads computation across hundreds of cycles diluting the signal.

4. **Clipping must be filtered** — Zkne hardware instructions cause large power spikes for certain plaintexts. Traces where the ADC clips (|signal| ≥ 0.49) must be discarded; approximately 45% of captures clip at any gain setting above 10dB.

---

## Reproducing the Experiments

### Requirements
```
chipwhisperer >= 6.0
numpy
scipy
matplotlib
```

### Steps
1. Connect CW305 and ChipWhisperer-Lite as described in Hardware Setup
2. Open `notebooks/sca_final_experiments.ipynb` in Jupyter
3. Update the bitstream paths in Cell 1 to match your machine
4. Run cells sequentially

### To attack saved traces (no hardware needed)
1. Open the notebook
2. Skip Cells 2-10 (hardware capture)
3. Run Cell 11 after loading traces from `traces/zkne_clean/`
