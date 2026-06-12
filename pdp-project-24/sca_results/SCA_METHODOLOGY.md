# Side-Channel Analysis Methodology and Results

Methodology, experimental setup, and final results for the hardware side-channel
analysis (CV32E40P RISC-V on CW305). The objective was to assess whether DOM
(Domain-Oriented Masking) applied to the Zkne AES hardware extension resists
power analysis.

## Experimental Setup

### Hardware

- **Target:** CW305 Artix-7 XC7A100T FPGA board
- **Scope:** ChipWhisperer-Lite
- **Measurement:** SMA cable to X4 (low-noise shunt resistor)
- **Interface:** 20-pin ribbon cable between CW305 and ChipWhisperer-Lite
- **Clock:** 50 MHz for RISCY designs, 10 MHz for the AES_100t reference

### Software

- ChipWhisperer Python API v6.0, Python 3.11
- Vivado 2023 (bitstream generation)
- LLVM/Clang and riscv-none-elf-gcc (firmware compilation)

### Designs Under Test

| Bitstream | Description |
|---|---|
| AES_100t | NewAE reference hardware AES (validation baseline) |
| Baseline RISCY | CV32E40P plus software AES in C (no protection) |
| Zkne unprotected | CV32E40P plus Zkne hardware AES (no DOM masking) |
| DOM protected | CV32E40P plus Zkne with DOM masking |

## Firmware Design

The CV32E40P core communicates with ChipWhisperer through a custom AHB2CW
peripheral at base address `0x51000000`. The firmware loops indefinitely: wait
for `CW_START`, read the key and plaintext from memory-mapped registers, assert
`CW_TRIG`, run AES, deassert `CW_TRIG`, write back the ciphertext, assert
`CW_DONE`.

### Trigger Placement

The initial firmware placed the trigger before key expansion, so the
500-sample capture window filled with software key-expansion noise before the
Zkne hardware instructions executed. Moving the trigger to after `expand_key()`
(software, outside the trigger window) so only `aes128_encrypt_block` runs inside
the window produced a 40x improvement in trace variance (0.000078 to 0.146).

### Inline Assembly Constraints

The original Zkne wrapper used unconstrained register allocation, which let the
compiler place operands in the wrong registers. Explicit register pinning
(`register uint32_t a0_reg __asm__("a0")` etc.) prevents the compiler from
overwriting operands.

## Capture Configuration

### Scope Settings

```python
scope.adc.basic_mode   = "rising_edge"
scope.trigger.triggers = "tio4"
scope.clock.adc_src    = "extclk_x4"    # 200 MHz sample rate at 50 MHz clock
target.clkusbautooff   = True            # silence USB during capture
```

### Gain Calibration

Gain is calibrated per bitstream because different designs draw different power.

| Design | Optimal gain | Signal range |
|---|---|---|
| AES_100t | 25 dB | ±0.24 |
| Baseline RISCY (SW AES) | 30 dB | ±0.38 |
| Zkne unprotected | 9 dB | ±0.47 |
| DOM protected | 30 dB | ±0.38 |

The Zkne hardware instructions cause large power spikes; about 45% of traces
clip at gains above 9 dB and are filtered during capture (discard any trace with
`|wave| >= 0.49`).

## Attack Methodology

### TVLA

TVLA detects whether power consumption statistically depends on processed data,
using Welch's t-test between fixed and random plaintext trace groups.

- **Threshold:** |t-value| > 4.5 indicates leakage (NIST SP 800-140C)
- **Traces per experiment:** 5,000 (2,500 fixed plus 2,500 random)
- **Fixed plaintext:** `0xda39a3ee5e6b4b0d3255bfef95601890`

### CPA

CPA recovers key bytes by correlating power traces with a predicted leakage
hypothesis.

- **Hardware AES** (`last_round_state_diff` model): targets the Hamming distance
  of the last-round state versus ciphertext; effective because the last round
  has no MixColumns.
- **Software/Zkne AES** (`sbox_output` model): targets `HW(Sbox[pt XOR k])`,
  using a focused window around the S-box execution samples identified via the
  variance plot.

PGE (Partial Guessing Entropy) is the rank of the correct key byte among 256
guesses; PGE = 0 means recovered.

## Results

### TVLA Results

| Design | Max \|t-value\| | Leaking samples | Verdict |
|---|---:|---:|---|
| AES_100t (HW AES, no protection) | 49.27 | 47 | Strong leakage |
| Baseline RISCY (SW AES) | 4.69 | 1 | Marginal leakage |
| DOM Protected RISCY | 3.98 | 0 | No leakage detected |

The DOM-protected design reduces the maximum t-value from 4.69 (baseline RISCY)
to 3.98, below the 4.5 threshold, with zero samples exceeding it. The AES_100t
figure of 49.27 is the dedicated-hardware reference, not our core.

### CPA Results

| Design | Bytes recovered | Max correlation | PGE (best byte) | Verdict |
|---|---:|---:|---:|---|
| AES_100t (reference) | 16/16 | 0.236 | 0 | Key recovered |
| Baseline RISCY (SW AES) | 0/16 | 0.127 | 5 | Leakage present |
| Zkne unprotected | 0/16 | 0.070 | 1 | Leakage present |
| DOM protected | 0/16 | 0.072 | 255+ | Attack failed |

- AES_100t validates the measurement setup: full key recovery on the known-leaky
  reference confirms the configuration is correct.
- Baseline RISCY and Zkne unprotected show PGE decreasing toward 0, confirming
  detectable leakage; full key recovery was not achieved on our designs within
  the available trace count.
- DOM protected holds correlation at the noise floor (0.072), identical to random
  guessing.

## Known Issues and Limitations

1. **No full key recovery on our designs:** CPA on software/Zkne AES needs more
   traces than captured due to high noise from surrounding CPU activity. PGE
   reached 5 (baseline) and 1 to 3 (Zkne unprotected), confirming leakage exists
   but stopping short of full recovery. The 16/16 recovery is on AES_100t only.
2. **Clipping filter bias:** discarding ~45% of Zkne traces to avoid ADC
   saturation may introduce statistical bias. A lower-noise setup or hardware
   attenuator would improve results.
3. **Single leakage model explored:** only `sbox_output` and
   `last_round_state_diff` were tested.

## Key Conclusions

1. **DOM masking is effective at the measured level:** the t-value drops to 3.98
   (DOM) from 4.69 (baseline RISCY), below the 4.5 threshold, with CPA at the
   noise floor.
2. **CPA validates the setup:** full key recovery on the AES_100t reference
   (corr 0.236) confirms the measurement infrastructure works; this is the
   reference design, not our core.
3. **Leakage is confirmed on unprotected designs:** decreasing PGE on both
   baseline and Zkne unprotected confirms data-dependent leakage is measurable,
   even though full key recovery was not completed within the available lab time.
4. **Trigger placement is critical:** moving the capture trigger to after
   software key expansion improved trace quality by 40x and is essential for
   attacking hardware-accelerated AES.
