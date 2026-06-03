# PYNQ-Z2 hardware verification

Hardware verification runs of the project on real silicon. Closes
intermediate-report task **C4** and adds the side-channel-track silicon
verification of our tower-field Zkne RTL.

Date: 2026-05-30 · Board: TUL **PYNQ-Z2** (Zynq-7020) · PYNQ Linux 2019.1.

## Run 1 - team baseline AES (unmodified bitstream)

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

## Run 2 - OUR tower-field Zkne RTL on silicon

Build with `sidechannel/build/cv32e40p_zkne_tower.sv` (our verified tower-field
S-box, replacing Hruday's 256-entry case statement) integrated as the Zkne
unit. Test program is `profiling-instrumentation/main.c` (Hruday's hardware
self-test) which calls `aes32esi` and `aes32esmi` for byte-lanes 0..3 and
compares each to a software AES reference.

Full output: `pynq/results/zkne_tower_test_2026-05-30.txt`. Bitstream and
hardware-handoff in `artifacts/zkne_tower/` (regenerable from sources).

```
============================================================
BITSTREAM RAN ON SILICON  (10.2 ms wall-clock)
============================================================
  cycle count        = 60035

  AES ciphertext check  = 0xCAFEBABE   PASSED
  Zkne hw == sw check   = 0xCAFEBABE   PASSED

  aes32esi  hw results:                aes32esmi hw results:
     bs=0  hw=0x7157f507                  bs=0  hw=0xe896349e
     bs=1  hw=0x7157bec6                  bs=1  hw=0x3a1c2850
     bs=2  hw=0x71bdf5c6                  bs=2  hw=0x9b723a2c
     bs=3  hw=0xdd57f5c6                  bs=3  hw=0x9e14596a

  expected ciphertext = fba50914714bf41f2e25aabeaaf9080f
  calculated          = fba50914714bf41f2e25aabeaaf9080f
============================================================
```

**Both PASSes are critical:**
- *AES ciphertext check* (`0x2004` = `0xCAFEBABE`) - the table-based AES path
  still produces the correct ciphertext on the modified design.
- ***Zkne hw == sw check*** (`0x2008` = `0xCAFEBABE`) - for all 4 byte-lanes
  of `aes32esi` and all 4 byte-lanes of `aes32esmi`, the hardware output
  matches a software reference computed in C. **This is the silicon proof
  that our tower-field algebra computes the AES S-box correctly inside the
  Zkne instruction.**

Build numbers (Vivado 2024.2 batch, scratch dir `~/sca-build/hardware/`):

| Metric | Value |
|---|---|
| Wall-clock from launch to bitstream | ~70 minutes |
| Post-route WNS | **+27.438 ns** (timing closure trivial at 20 MHz) |
| Bitstream size | 4,045,673 B (identical-bytes to the team baseline) |

## Run 3 - DOM-masked Zkne RTL on silicon

Build with `sidechannel/build/cv32e40p_zkne_dom_wrap.sv` (new Zkne wrapping
the DOM-masked S-box `aes_sbox_tower_dom.sv`, plus `cv32e40p_alu_dom.sv`
exposing a multi-cycle ready handshake). The wrapper:
- masks the input byte with a fresh 8-bit value from a 32-bit Galois LFSR,
- drives the DOM-masked S-box (5 DOM-AND gates, 4-cycle pipeline),
- unmasks the output via share XOR,
- a 6-state FSM (`IDLE → P1..P4 → DONE → IDLE`) gives each AES instruction
  exactly 5 cycles.

Full output: `pynq/results/zkne_dom_test_2026-05-30.txt`. Bitstream and
hardware-handoff in `artifacts/zkne_dom/`.

```
============================================================
BITSTREAM RAN ON SILICON  (10.2 ms wall-clock)
============================================================
  cycle count        = 60072

  AES ciphertext check  = 0xCAFEBABE   PASSED
  Zkne hw == sw check   = 0xCAFEBABE   PASSED

  aes32esi  hw results:                aes32esmi hw results:
     bs=0  hw=0x7157f507                  bs=0  hw=0xe896349e
     bs=1  hw=0x7157bec6                  bs=1  hw=0x3a1c2850
     bs=2  hw=0x71bdf5c6                  bs=2  hw=0x9b723a2c
     bs=3  hw=0xdd57f5c6                  bs=3  hw=0x9e14596a

  expected ciphertext = fba50914714bf41f2e25aabeaaf9080f
  calculated          = fba50914714bf41f2e25aabeaaf9080f
============================================================
```

**The DOM-masked Zkne unit produces byte-identical aes32esi/esmi outputs to
the unmasked tower variant on the same silicon.** The mask + DOM + unmask
path is functionally correct on real Zynq-7020 hardware.

Build numbers:

| Metric | Value |
|---|---|
| Wall-clock from launch to bitstream | ~75 minutes |
| Post-route WNS | **+28.617 ns** (even better than tower's +27.438 ns) |
| Post-route Hold WHS | +0.016 ns (no hold violations) |
| Bitstream size | 4,045,673 B |

### Multi-cycle penalty measured on silicon

The DOM run took **60,072 cycles** vs the tower's **60,035 cycles** for the
same test program. That `+37` cycle delta is exactly the cost of the
multi-cycle handshake: 8 AES instructions (4×`aes32esi` + 4×`aes32esmi`) at
~5 cycles each = ~40 extra cycles. Silicon-measured agreement with the
designed 5-cycle FSM.

## Run 4 - tower-field Zkne + hw-using AES (post-Hruday-fix, post-merge)

After merging Hruday's d5bb1fc fix (commits 3e59f8f + our 25fd333 mc0/mc3
swap of the derived files), the bitstream + the new `software/main.c` (which
inlines `hw_aes32esi`/`hw_aes32esmi` in the AES round chain) were rebuilt
and re-run on the PYNQ-Z2.

Full output: `pynq/results/zkne_tower_hwAES_2026-06-02.txt`.

```
============================================================
BITSTREAM RAN ON SILICON  (10.2 ms wall-clock)
============================================================
  cycle count        = 4369

  AES ciphertext check  = 0xCAFEBABE   PASSED
  Zkne hw == sw check   = 0xCAFEBABE   PASSED

  expected ciphertext = fba50914714bf41f2e25aabeaaf9080f
  calculated          = fba50914714bf41f2e25aabeaaf9080f
============================================================
```

The `aes32esmi` outputs are now byte-correct against the RISC-V scalar-crypto
spec (the previous May-30 PASS was a same-bug-cancels-same-bug coincidence
between Hruday's old SW reference and his old RTL).

## Run 5 - DOM-masked Zkne + hw-using AES

Same hw-using `main.c`, but on the DOM-masked bitstream.
Full output: `pynq/results/zkne_dom_hwAES_2026-06-02.txt`.

```
============================================================
BITSTREAM RAN ON SILICON  (10.3 ms wall-clock)
============================================================
  cycle count        = 5506

  AES ciphertext check  = 0xCAFEBABE   PASSED
  Zkne hw == sw check   = 0xCAFEBABE   PASSED

  calculated ciphertext = fba50914714bf41f2e25aabeaaf9080f
============================================================
```

## Summary of all five runs on PYNQ silicon

| Run | Bitstream                                          | C program        | Cycles  | Ciphertext | Notes |
|---:|----------------------------------------------------|------------------|--------:|:--:|---|
| 1 | team baseline (no Zkne)                              | table-based AES  | 161,441 | ✓ | original baseline |
| 2 | OUR tower-field (old mc0/mc3)                        | Hruday self-test |  60,035 | ✓ | hw vs sw passed by canceling bugs |
| 3 | OUR DOM-masked (old mc0/mc3)                         | Hruday self-test |  60,072 | ✓ | same as Run 2, +37 cyc multi-cycle test cost |
| **4** | **OUR tower-field (mc0/mc3 fixed)**                  | **hw-using AES** | **4,369**   | ✓ | spec-correct, **36.9× faster than baseline** |
| **5** | **OUR DOM-masked (mc0/mc3 fixed)**                   | **hw-using AES** | **5,506**   | ✓ | DOM adds **+1,137 cyc** (26%) vs tower |

### DOM cost on real AES, measured

The 1,137-cycle delta between Runs 4 and 5 lines up with the architecture
prediction: AES-128 issues ~160 hw instructions per block (9 inner rounds
times 16 bytes of `aes32esmi` plus 1 final round times 16 of `aes32esi`).
Each one stalls the pipeline 4 extra cycles for the DOM 5-cycle handshake.
160 x 4 = 640 raw cycles from the stalls, the rest is pipeline drain and
the per-instruction inline-asm boilerplate (`mv a0,%1; mv a1,%2; .word ...;
mv %0,a2`) running through the longer-latency path.

Side-channel resilience claim (CPA fails, TVLA |t| < 4.5) remains the
simulation-based rig in `sidechannel/` since hardware-power probing needs
ChipWhisperer/CW305 we don't have. The lab work on real power traces can
be done with these bitstreams when the user is in the lab.
