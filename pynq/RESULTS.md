# PYNQ-Z2 hardware verification

First successful end-to-end run of the AES baseline on real silicon for this
project. Closes intermediate-report task **C4** ("Upload bitstream to PYNQ-Z1
via Jupyter; run the `base_riscy.ipynb` notebook; verify wall-clock AES output
matches simulation").

Date: 2026-05-30 · Board: TUL **PYNQ-Z2** (Zynq-7020) · PYNQ Linux 2019.1.

## Result

Full output: `pynq/results/baseline_aes_2026-05-30.txt`

```
============================================================
AES RAN ON SILICON ✓     (10.2 ms wall-clock)
============================================================
  cycle count    = 161441    (sim baseline = 59560)
  expected       = fba50914714bf41f2e25aabeaaf9080f
  calculated     = fba50914714bf41f2e25aabeaaf9080f
  result_check   = 0xcafebabe  PASSED ✓
============================================================
```

**Ciphertext matches the expected value byte-for-byte**, so the full chain
(C source → COE → bitstream → PL on real Zynq → AXI BRAM I/O → register
bank → host readback) is end-to-end correct.

## The simulation vs silicon cycle gap

| Source | Cycles | Notes |
|---|---:|---|
| Our sim (`zynq_tb.sv`, `mem_snoop_match.CLK_COUNT`) | 59,560 | behavioural BRAMs, idealized AXI |
| Course PDF reference | 161,441 | published figure |
| **This silicon run** (PS-readable `reg_bank[0x4]`) | **161,441** | exact match to course figure |

The simulation is **~2.7× optimistic** vs silicon. The gap is real BRAM read
pipelining and AXI smartconnect arbitration that the behavioural TB does not
model. This matters for the choice of baseline:

- For the **side-channel before/after** comparison, the *simulation* is the
  correct yardstick (same TB drives both unprotected and DOM rigs → cycle
  delta is comparable).
- For any **project-wide speedup-vs-baseline** claim ("we made AES X% faster
  on the real chip"), the **161,441 silicon number** is the baseline to beat.

## How we got here without an SD-card flash

The board's pre-existing SD image (PYNQ Linux 2019.1) was alive and on the
network, but configured **DHCP-only**, not the older static `192.168.2.99`
fallback. The breakthrough chain:

1. `openocd` over the FTDI USB-JTAG saw both the PL and the ARM tap.
2. Halting the ARM showed the PC in Linux kernel address space (`0xc01177a8`)
   → the OS was running, just unreachable from the network.
3. `tcpdump` on `enp0s31f6` caught the PYNQ broadcasting DHCP requests every
   ~3 s with MAC `00:05:6b:04:0c:29` (Trenz OUI = PYNQ-Z2 vendor).
4. A throw-away `dnsmasq` on the laptop handed it `192.168.2.119`.
5. SSH `xilinx`/`xilinx` worked; `sudo python3` runs `pynq.Overlay`.
6. The team's pre-existing `riscy/overlays/base_riscy.bit` + `mem_files/*.coe`
   were already on the board from April 2025 — no upload needed.

## Reproducing

Pre-requisites on the laptop (one-time):

```bash
sudo ip addr add 192.168.2.1/24 dev enp0s31f6
sudo nmcli device set enp0s31f6 managed no
sudo dnsmasq --listen-address=192.168.2.1 --bind-interfaces --no-resolv \
    --port=0 --dhcp-range=192.168.2.50,192.168.2.150,255.255.255.0,5m \
    --dhcp-authoritative --pid-file=/tmp/dnsmasq.pid
```

Then to run an AES test (any time the board is plugged in):

```bash
./scripts/run-on-pynq.sh
```

The IP the PYNQ lands on may vary inside the DHCP range. Override with
`PYNQ_IP=192.168.2.<n> ./scripts/run-on-pynq.sh` if needed.

## Why the DOM-masked bitstream wasn't run on silicon

For the side-channel deliverable specifically, running on PYNQ would not add
new evidence:

- **Functional correctness of the DOM module** is already proven by the
  exhaustive 5256/5256 unit-test (`tb_sbox_tower_dom.sv`).
- **The side-channel claim itself** (CPA fails, TVLA passes) is a
  power-measurement claim. We have no ChipWhisperer / CW305, so the on-silicon
  run would produce identical functional output without giving any new SCA
  evidence. The simulation-based leakage rig in `sidechannel/` *is* the
  evidence.

Cost of doing it anyway, for completeness: write a full-system Vivado project
integrating `cv32e40p_zkne_dom` in place of Hruday's `cv32e40p_zkne` (+ ALU
multi-cycle handshake), synth and bitstream (~20 min on the server), rerun.
This is feasible but not required for Daniel's deliverable.
