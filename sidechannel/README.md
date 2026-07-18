# Side-channel leakage rig (Group 24)

Simulation-based side-channel attack + countermeasure work for the Zkne AES
unit. Design rationale: `../docs/superpowers/specs/2026-05-25-sidechannel-dom-design.md`.

**No ChipWhisperer** → "power" comes from an RTL simulation model: drive many
plaintexts through `cv32e40p_zkne`, capture the result register, and log
`HammingWeight(result)` per trace. CPA recovers the key; TVLA quantifies
leakage. The DOM-protected module (later) is judged on the *same* rig.

```
sidechannel/
├── tb/tb_zkne_leak.sv     # unit testbench (loops N traces, writes CSV)
├── sim/run_leak_xsim.sh   # runs ON SERVER (~/sca): xvlog→xelab→xsim
├── analysis/cpa.py        # CPA key recovery + plots (laptop)
├── analysis/tvla.py       # Welch fixed-vs-random t-test + plots (laptop)
└── out/                   # CSVs pulled from server + generated PNGs
```

## Run order

Sim runs on the **server** (Vivado xsim); analysis runs on the **laptop**
(numpy/scipy). Only the small CSV crosses the wire.

### 1. Push the harness to the server (laptop)

```bash
./scripts/push-sca.sh           # copies tb + sim + analysis + DUT RTL → server:~/sca/
```

### 2. Simulate on the server (laptop drives it over SSH)

```bash
# CPA dataset: 20k random plaintexts, hidden key byte 0x2b (=43)
./scripts/connect-server.sh 'cd ~/sca && ./sim/run_leak_xsim.sh \
    num_traces=20000 key_byte=43 tvla=0 outfile=out/cpa.csv'

# TVLA dataset: 40k traces, fixed-vs-random
./scripts/connect-server.sh 'cd ~/sca && ./sim/run_leak_xsim.sh \
    num_traces=40000 tvla=1 fixed_pt=0 key_byte=43 outfile=out/tvla.csv'
```

### 3. Pull the CSVs back (laptop)

```bash
./scripts/fetch-from-server.sh '~/sca/out/cpa.csv'  ./sidechannel/out/
./scripts/fetch-from-server.sh '~/sca/out/tvla.csv' ./sidechannel/out/
```

### 4. Attack / assess (laptop)

```bash
cd sidechannel/analysis

# CPA: recover the key byte (we pass the true byte only to verify + label plots)
python3 cpa.py --csv ../out/cpa.csv --true 0x2b --noise 2.0 --out ../out/cpa

# TVLA: fixed-vs-random leakage test
python3 tvla.py --csv ../out/tvla.csv --noise 2.0 --out ../out/tvla
```

`cpa.py` prints the recovered key byte, its rank, and traces-to-disclosure, and
writes `cpa_corr_vs_guess.png` + `cpa_convergence.png`. `tvla.py` prints the
Welch t and writes `tvla_tcurve.png`.

## Testbench plusargs

| plusarg | default | meaning |
|---|---|---|
| `num_traces` | 20000 | number of traces (one S-box op each) |
| `seed` | 1 | `$urandom` seed (reproducible) |
| `key_byte` | 0x2b | hidden key byte the attack recovers |
| `tvla` | 0 | 0 = CPA (all random), 1 = TVLA (fixed vs random) |
| `fixed_pt` | 0 | fixed-group plaintext byte (TVLA) |
| `op` | 0 | 0 = aes32esi (SubBytes only), 1 = aes32esmi |
| `bs` | 0 | byte lane 0..3 |
| `outfile` | out/traces.csv | CSV path (relative to ~/sca) |
| `vcd` | 0 | 1 = also dump `out/zkne_leak.vcd` (debug) |

## Phases

- **P1/P2 (now):** rig + attack the **unprotected** `cv32e40p_zkne` → recover
  the key, report TVLA |t|. This is the professor's "setup working + attack the
  baseline" milestone.
- **P3:** DOM-protected `cv32e40p_zkne_dom` (tower-field masked S-box).
- **P4:** rerun this rig on the DOM module → CPA fails, |t| < 4.5.
- **P5:** `SIDECHANNEL.md` writeup + inline RTL docs.
