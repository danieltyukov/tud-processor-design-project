# PDP Project — Session Notes: Loop Unrolling via Custom LLVM Pass (+ design discussion)

Working notes covering: code review of the DOM-protected AES branch, the software
build/simulation flow, three ways we achieved loop unrolling (pragma, GCC flag,
and a **custom LLVM pass**), measured cycle results, and forward-looking design
discussion (superinstructions, 4-source encoding, parallel S-boxes, RTL levers).

Target: CV32E40P (RI5CY) on Zynq PYNQ-Z1, AES-128 with DOM-protected `aes32esi` /
`aes32esmi` (OpenTitan masked S-box). Plaintext `"Hello, World!000"`, key
`"cese4040password"`, expected ciphertext `fba50914 714bf41f 2e25aabe aaf9080f`.

---

## 1. Code review (DOM branch)

Reviewed the branch's changed files (DOM S-box port, Zkne-DOM execution unit,
EX-stage integration, primitives, testbench, `main.c`). Conclusion: logically
sound and functionally correct (sim passes, correct ciphertext).

Items flagged:
- **Two `$display` "TEMPORARY DEBUG" blocks** still present — one in
  `cv32e40p_zkne_dom.sv` (~line 216), one in `cv32e40p_ex_stage.sv` (~line 437).
  They spam the sim log; remove before final submission.
- **LFSR fixed seed** `64'hDEAD_BEEF_CAFE_1234` in `cv32e40p_zkne_dom.sv` — fully
  deterministic PRD. Fine for course/sim; a real deployment needs a TRNG.
- Everything else (GF arithmetic, basis matrices, 5-cycle S-box sequencing,
  stall/`ready_o` logic, forwarding mux, MixColumns, `main.c`) checks out.

---

## 2. Software build + simulation flow

### Environment (WSL, Ubuntu)
- Project: `/mnt/c/Users/msath/Downloads/pdp-project`
- RISC-V GCC: `riscv64-unknown-elf-gcc` (+ picolibc), system clang/LLVM **21**
- picolibc include: `/usr/lib/picolibc/riscv64-unknown-elf/include`
- picolibc lib (rv32imac/ilp32): `/usr/lib/picolibc/riscv64-unknown-elf/lib/rv32imac/ilp32`
- LLVM cmake: `/usr/lib/llvm-21/lib/cmake/llvm`

> Note: the project's `rv32-standard.conf` points at server paths
> (`/data/mirror/...`) that don't exist locally, so we built with the system
> RISC-V GCC + picolibc, and the system clang/LLVM 21 for the pass.

### One-time prerequisites
```bash
sudo apt install -y gcc-riscv64-unknown-elf lld
sudo apt install -y clang llvm-21-dev cmake ninja-build
```

### Full build → COE → sim (with the custom pass)
```bash
# --- variables (per shell session) ---
cd /mnt/c/Users/msath/Downloads/pdp-project/software
GCC=riscv64-unknown-elf-gcc
OBJCOPY=riscv64-unknown-elf-objcopy
ARCH="-march=rv32imac_zicsr -mabi=ilp32"
PICOINC=/usr/lib/picolibc/riscv64-unknown-elf/include
PICOLIB=/usr/lib/picolibc/riscv64-unknown-elf/lib/rv32imac/ilp32
PLUGIN=../compiler/aes-unroll-pass/build/libAESUnroll.so
GCFLAGS="-Os -std=gnu11 -nostartfiles -ffunction-sections -fdata-sections -msmall-data-limit=8 -Iinclude -Isoft -g3 -I$PICOINC"
mkdir -p output bin_files

# --- support objects (GCC, unchanged) ---
$GCC $ARCH $GCFLAGS -c include/utils.c      -o _utils.o
$GCC $ARCH $GCFLAGS -c include/tcutils.c    -o _tcutils.o
$GCC $ARCH $GCFLAGS -c include/int.c        -o _int.o
$GCC $ARCH $GCFLAGS -c include/exceptions.c -o _exc.o
$GCC $ARCH $GCFLAGS -x assembler-with-cpp -c crt0.riscv.S -o _crt0.o

# --- main.c via clang + our custom unroll pass (-Os so the loop pipeline runs) ---
clang --target=riscv32-unknown-elf $ARCH \
  -Os -std=gnu11 -nostdlib -ffunction-sections -fdata-sections \
  -msmall-data-limit=8 -Iinclude -Isoft -I$PICOINC \
  -fpass-plugin=$PLUGIN \
  -c main.c -o _main.o
#   -> prints: [AESUnroll] fully unrolled AES loop '...' (x9) ...

# --- link (GCC driver + picolibc; clang-built main.o links fine) ---
$GCC $ARCH -nostartfiles -nostdlib -Wl,--build-id=none -Wl,--gc-sections \
  -T link.common.ld _crt0.o _main.o _utils.o _tcutils.o _int.o _exc.o \
  -L$PICOLIB -lc -lgcc -o output/soft.elf

# --- verify unroll (40 = looped, ~168 = fully unrolled) ---
echo -n "aes32 instruction count: "
riscv64-unknown-elf-objdump -d output/soft.elf | grep -c 'b50613'

# --- ELF -> SREC -> COE -> copy into sim mem_files ---
$OBJCOPY -O srec output/soft.elf output/soft.srec
python3 python_script/srec_to_coe.py output/soft.srec -b 0x8000   -s 0x8000 -f -o bin_files/code.coe
python3 python_script/srec_to_coe.py output/soft.srec -b 0x100000 -s 0x8000 -f -o bin_files/data.coe
cp bin_files/code.coe ../hardware/src/sw/mem_files/code.coe
cp bin_files/data.coe ../hardware/src/sw/mem_files/data.coe
```

### Vivado simulation (Tcl console, not WSL)
```tcl
cd C:/Users/msath/Downloads/pdp-project/hardware
source scripts/create_project.tcl     ;# first time in a fresh Vivado session
source scripts/run_simulation.tcl      ;# reloads .coe, runs to completion
# -> "Test completed in N clk cycles" / "Test PASSED"
```

### Rebuild shortcuts
- Edited `main.c`: redo clang compile → link → COE → re-run `run_simulation.tcl`.
- Edited the pass (`AESUnroll.cpp`): `cmake --build build`, then the above.
- Baseline (loop NOT unrolled): same clang line **without** `-fpass-plugin` → count 40.

---

## 3. Loop unrolling — three approaches

The AES round loop (`main.c`, `aes128_encrypt_block`) is 9 iterations × 16
`hw_aes32esmi` calls; the final round is 16 straight-line `hw_aes32esi`.

| Approach | How | Source edit? | Notes |
|---|---|---|---|
| `#pragma GCC unroll 9` | directive in source | yes | overrides cost model at `-Os` |
| `-O2 -funroll-loops` + `--param` bumps | compiler flag | no | built-in unroller; `-Os` refuses to grow code |
| **Custom LLVM pass** | `-fpass-plugin=libAESUnroll.so` | **no** | **our own pass**, the chosen deliverable |

Instruction-count check (`grep -c 'b50613'` on the ELF): **40 = looped**,
**168 = fully unrolled** (144 esmi + 16 esi + 8 from `test_zkne`).

---

## 4. The custom LLVM pass

Location in repo:
```
compiler/aes-unroll-pass/
├── AESUnroll.cpp     # the pass (new pass manager, out-of-tree plugin)
├── CMakeLists.txt    # build recipe
└── build/libAESUnroll.so   # compiled plugin (generated)
```

### Build
```bash
cd /mnt/c/Users/msath/Downloads/pdp-project/compiler/aes-unroll-pass
cmake -S . -B build -G Ninja \
  -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm \
  -DCMAKE_CXX_COMPILER=clang++
cmake --build build
```

### What it does
- Registers at the **LoopOptimizerEnd** extension point (so the loop is already in
  simplified + rotated + LCSSA form with a computable trip count).
- Identifies the AES round loop **robustly** — any natural loop whose body contains
  an **inline-asm call** (the `aes32esmi`/`aes32esi` `.word` encodings). This
  survives inlining and doesn't rely on function names.
- Reads the constant trip count via **ScalarEvolution**, then calls LLVM's
  **`UnrollLoop()`** utility directly with `Count = tripcount, Force = true` to
  fully unroll. (We drive the unroll ourselves — the built-in
  `LoopFullUnrollPass`/`-funroll-loops` cost model never makes the decision.)
- Prints `[AESUnroll] fully unrolled AES loop ... (x9) ...` and marks the loop
  deleted to the loop pass manager.

This is an **IR (mid-end)** pass, which is why an **out-of-tree plugin** against the
system LLVM works (no LLVM source rebuild). A *backend* instruction change (e.g.
superinstructions, see §6) would instead need the **in-tree** LLVM workflow the
project README describes.

---

## 5. Results (DOM-protected core, all `Test PASSED`)

| Build | Compiler | Unroll method | Cycles |
|---|---|---|---|
| Looped | GCC `-Os` | none | 6,260 |
| Unrolled | GCC `-Os` | `#pragma` | 6,067 |
| Unrolled | GCC `-O2` | `-funroll-loops` (built-in) | 5,509 |
| **Unrolled** | **clang `-Os`** | **custom AESUnroll pass** | **4,800** |

**Attribution caveats (important for the report):**
- `#pragma` at `-Os` (6,067) isolates *unrolling alone* on GCC: ≈ **190 cycles (3%)**.
- GCC `-O2` flag (5,509) bundles unrolling with other `-O2` codegen gains.
- clang `-Os` + our pass (4,800) is lowest, but crosses compilers — part of the
  gap is clang's tighter `-Os` codegen, part is the unroll. The clean "unroll-only"
  delta would be clang+plugin vs clang-no-plugin (both `-Os`); we have the
  no-plugin instruction count (40) but didn't sim it for cycles.

All builds produce the correct ciphertext.

### 5b. Hardware: 2-wide fused DOM S-box (`parallel-sbox` branch)

Built a fused **2-lane** AES instruction: two OpenTitan `aes_sbox_dom` S-boxes run
in parallel and emit two half-column lanes (`cv32e40p_zkne_dom2.sv`); software
XORs the two halves + round key. The 9 middle rounds use `aescolmi2`
(SubBytes+MixColumns) and the final round uses `aescolsi2` (SubBytes only) — 8
fused ops per round instead of 16 scalar. Scalar `aes32esi/esmi` path kept intact
as fallback.

| Build (all on top of the custom unroll pass) | Cycles | Δ |
|---|---|---|
| Unroll only (scalar DOM) | 4,800 | — |
| + fused `esmi2`, rounds 1–9 | 4,121 | −679 |
| + fused `esi2`, final round | **4,104** | −17 |

**End-to-end: 6,260 → 4,104 = 34.4% faster, DOM intact.** Only ~14% over
unroll-alone because each fused op still pays the full 5-cycle DOM latency +
whole-pipeline stall (parallel S-boxes cost the same as one scalar op); per-op
stall dominates, not op count.

**Encoding gotcha (cost one debug cycle):** the AES ops live in `OPCODE_OPIMM`
(`funct3=000`), distinguished only by `instr[29:25]` — which is part of an `ADDI`
immediate (`imm[9:5]`). Any compiler `addi` whose `imm[9:5]` equals an AES
discriminator is silently executed as an AES op, corrupting that register.
Symptom: correct ciphertext but clobbered post-encryption constants
(`0x2e25aabe`→imm `0xABE`, `0xDEADBEEF`→`0xEEF`, test-vector `0x12345678`→`0x678`).
Fix: choose discriminators absent from the binary's `addi imm[9:5]` set (objdump
the elf, compute `(word>>25)&0x1F` for every `addi`). Final values: esi=`10001`,
esmi=`10010`, esmi2=`10100`, esi2=`11000`. Safe because the colliding constants
are fixed *data*, and `.word` swaps don't shift code layout. A rebuild-time
self-check script greps the disassembly and asserts `COLLISIONS: 0`.

---

## 6. Design discussion: superinstructions / fusion

### Idea
Fuse the 4-instruction column chain
```c
n0 = aes32esmi(0,  s0, 0);
n0 = aes32esmi(n0, s1, 1);
n0 = aes32esmi(n0, s2, 2);
n0 = aes32esmi(n0, s3, 3);
```
into a single instruction that produces a full mixed column → one round goes from
16 instructions to 4.

### The encoding chosen: `rs4 | rs3 | rs2 | rs1 | rd | opcode`
- 4×5 (sources) + 5 (rd) + 7 (opcode) = **32 bits exactly** → **no funct/bs bits
  left**. Burns a whole major opcode; instruction must always process the full
  column (which is fine — no `bs` needed).

### The real problem: 4 source regs, only 2 read ports
CV32E40P has **2 read ports** (3 with FPU). Options considered:
1. **Add read ports** — rejected: grows area & hurts whole-core timing for one op.
2. **Multi-cycle (FSM) operand read** — read 2 regs/cycle over 2 cycles, latch into
   staging. **Chosen direction.**
   - Refinement: the DOM unit already stalls EX ~5 cycles, leaving the read ports
     **idle**. Borrow them — read `rs1,rs2` in ID, then `rs3,rs4` during the EX
     stall. The S-box consumes bytes serially anyway, so added latency ≈ **0**.
3. **Macro-op fusion** — keep the 2-source ISA, fuse the 4 `esmi` in the decoder.
   Avoids both the read-port problem and the encoding burn. Most elegant.
4. **Aligned "quad read" port** — constrain `s0..s3` to an aligned register group;
   one group-index decoder + 128-bit readout, single-cycle, far cheaper than 4
   general ports. Costs a regalloc/ABI pin.
5. **State-load + 4 column-produce ops** — read each source once into internal
   staging, then 4 GPR-read-free column ops. Cuts regfile read traffic.

---

## 7. Estimate: 2-cycle read + 4 parallel S-box units

Per-`esmi` steady-state cost from the waveforms ≈ **9–10 cycles** (~5 S-box +
~4–5 issue/handoff). Two independent savings:
1. **Parallel S-box** collapses 4 serial S-box latencies (4×5) into one (5) per column.
2. **Fusion** pays the issue/handoff overhead once per column instead of 4×.

| | Current (unrolled) | Fused + 4 units |
|---|---|---|
| SubBytes/MixColumns ops | 160 | **40** |
| Cost per op | ~9.5 cyc | ~8 cyc |
| DOM-region cycles | ~1,520 | ~320 |

**Saving ≈ 1,200 cycles ⇒ 4,800 → ~3,500–3,700 (≈ 22–27%).**
Speedup vs software baseline (61,184): ~12.7× → **~16–17×**.

Caveats:
- **Bottleneck shifts off the S-box** onto software glue (key expansion, round-key
  XORs, stores, boot, `test_zkne`). Next wins become compile-time key expansion /
  trimming the self-test.
- **Randomness scales 4×**: independent PRD per unit (~28 bits each ⇒ ~112
  bits/cycle); the 64-bit LFSR must be widened/strengthened for first-order security.
- **Area ~4×** the S-box logic (each ≈ 9 GF multipliers + ~28 flops); feasible on
  xc7z020 but check OOC utilization/timing.

---

## 8. Two RTL levers identified earlier (stack with the above)

1. **Dual / parallel DOM S-box** (in `cv32e40p_zkne_dom.sv`): route independent
   accumulator chains (`n0/n2` vs `n1/n3`) to separate `aes_sbox_dom` instances →
   roughly **halves** AES S-box cycles. (The "4 parallel units" in §7 is this lever
   taken further.)
2. **BRAM instruction-memory read latency 2 → 1** (`R_LATENCY_IN_CYCLES` in
   `core_2_bram.sv`): trims the ~5-cycle inter-instruction gap on every instruction
   ⇒ on the order of **~840 cycles**, and helps the *whole* program, not just AES.
   Cost: re-check timing closure. Independent of the S-box work, so it **stacks**.

---

## 9. Open / next steps
- (Optional) Sim the clang-no-plugin baseline for the clean "unroll-only" delta.
- Remove the two `$display` debug blocks before final submission.
- Add `compiler/aes-unroll-pass/README.md` so teammates can build/run the pass.
- If pursuing superinstructions: move to the **in-tree LLVM** backend workflow
  (modify RISC-V backend, rebuild clang/lld) — an IR plugin can't emit a new
  target instruction.
- Consider: compile-time key expansion + dropping `test_zkne` from the hot path
  once the S-box stops being the bottleneck.
```
