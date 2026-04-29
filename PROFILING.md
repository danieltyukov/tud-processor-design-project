# AES-128 Baseline — Static Profiling (2026-04-24)

Static instruction-count analysis of the baseline AES-128 software
implementation (`software/main.c`) as compiled by the course's LLVM
clang toolchain (`rv32imac_zicsr`, `-Os -O0`, `ilp32` ABI).

Source disassembly captured via:

```bash
export PATH=/data/mirror/riscv/bin:$PATH
riscv32-unknown-elf-objdump -d output/soft.elf > output/soft.s
```

## 1. Function layout in the compiled binary

From `grep "<.*>:" output/soft.s`, sorted by address:

| Function | Entry addr | Static instrs |
|---|---|---:|
| `expand_key` | 0x831e | 55 |
| `sub_bytes` | 0x83ce | 14 |
| `shift_rows` | 0x83f0 | 29 |
| `gf_mult` | 0x8452 | 20 *(also inlined in mix_columns)* |
| `mix_columns` | 0x8478 | 186 |
| `add_round_key` | 0x8638 | 13 |
| `aes128_encrypt_block` | 0x8654 | 175 |
| `aes128_ecb_encrypt` | 0x8862 | 33 |
| `main` | 0x88b8 | 61 |
| `memcpy` | 0x82e4 | 12 |
| `memset` | 0x82ce | 8 |

## 2. The hot spot: `mix_columns` dominates

Reading the disassembly of `mix_columns` (0x8478–0x8637, 186 static
instructions): the compiler **inlined** every one of the 8 calls to
`gf_mult()` that appear in each column-loop iteration. The result is 8
back-to-back 12-instruction loops, one per `gf_mult` invocation, all
inside the outer 4-iteration column loop.

Dynamic execution per `mix_columns` call:

```
4 columns × 8 inlined gf_mult loops × 8 loop-body instrs × 12 instrs/iter
    ≈ 3,100 instructions per column iteration
    × 4 column iterations
    ≈ 3,640 instructions per mix_columns call
```

Across **9 full rounds**: 9 × 3,640 ≈ **32,700 dynamic instructions**.

The final (10th) round skips `mix_columns` by design, so `mix_columns`
accounts for cycles in rounds 1–9 only.

## 3. Estimated dynamic instruction mix

| Function | Dyn. calls | Dyn. instrs | % of ~37k total |
|---|---:|---:|---:|
| **mix_columns** (incl. inlined gf_mult) | 9 | **~32,700** | **~55%** |
| add_round_key | 11 | ~1,232 | ~2% |
| sub_bytes | 10 | ~1,120 | ~2% |
| expand_key | 1 | ~874 | ~1.5% |
| aes128_encrypt_block glue | 1 | ~300 | ~0.5% |
| shift_rows | 10 | ~290 | ~0.5% |
| misc (main, memcpy, write_v_to_address) | — | ~500 | ~1% |
| **Total estimated instructions** | | **~37,000** | |

## 4. CPI analysis

Measured cycles: **59,560** (from `mem_snoop_match.CLK_COUNT`).
Estimated instructions: **~37,000**.

**CPI = 59,560 / 37,000 ≈ 1.61**

For a single-issue in-order CV32E40P core, a CPI well above 1.0
indicates significant stall cycles. Sources, in rough order:

1. **Data BRAM 2-cycle read latency** — confirmed by the
   `core_2_bram R_LATENCY_IN_CYCLES=2` parameter visible in the synth
   log. Every `lbu`/`sb` against the 16-byte state buffer pays the
   latency.
2. **Load-use delay slots** — the AES code has tight sequences of
   `lbu → arith → sb`. If result-forwarding doesn't fully cover the
   pattern, each dependency costs a bubble.
3. **Branch resolution on the 8-iteration gf_mult loop** — with a
   simple (or no) branch predictor, the `bnez` at each loop iteration
   may cost cycles.
4. **Byte-level operations on a 32-bit datapath** — every `zext.b` and
   `srai/slli` to isolate one byte adds instruction count beyond what
   the algorithm strictly requires.

## 5. Projected Phase 2 speedup

| Change | Cycles saved | Running total |
|---|---:|---:|
| Baseline | — | **59,560** |
| `aes32esmi` replaces inlined gf_mult + SubBytes + partial MixColumns in rounds 1–9 | ~−24,000 | ~35,500 |
| `aes32esi` replaces SubBytes in final round | ~−150 | ~35,400 |
| LLVM loop-unroll pass on outer mix_columns loop (4 iterations → fully unrolled) | ~−500 | ~34,900 |
| State held in registers instead of BRAM (reduces memory stalls) | ~−8,000 to −10,000 | **~25,000** |

**Conservative target: ~2.3× speedup** (59,560 → ~26,000 cycles).
**Aggressive target: ~3× speedup** (59,560 → ~20,000 cycles) if
`aes32esmi`'s built-in XOR tree eliminates the inter-lane XOR chain as
well.

## 6. Why this matches the course's mandatory deliverables

The RISC-V Zkne scalar-crypto `aes32esmi` instruction (v0.9.3 spec)
performs, in one cycle:

1. Extract byte `bs` from `rs2`.
2. Apply the AES S-box to that byte.
3. Multiply the result by the MixColumns matrix row (partial, one
   lane).
4. Rotate to the correct byte position.
5. XOR with `rs1`.

That is **exactly** the body of one inlined `gf_mult` invocation plus
the surrounding SBox + XOR in our disassembly. Replacing ~80 RISC-V
instructions (plus memory traffic) with a single `aes32esmi` per
SBox+MixColumns lane is why the expected savings are large.

The LLVM loop-unroll pass is orthogonal: it removes the outer
4-iteration column-loop overhead in `mix_columns`. Modest saving, but
required by the deliverable and easy to implement once the intrinsic
is wired in.

## 7. What we have NOT measured (yet)

This is a **static** analysis — instruction counts derived from the
disassembly plus structural reading of the C source. The CPI number is
derived, not measured per-function. To get per-function cycle
attributions we need **dynamic profiling** (Task 6 in TODO):

- Wrap each AES function with `rdcycle` reads (mcycle CSR).
- Rebuild `make soft`, re-run sim, print the per-phase deltas.
- Compare to the static estimate above.

Static + dynamic together give the intermediate report its
"quantitative evidence" section.

## 8. Artifacts

- Full disassembly: `software/output/soft.s` (1,029 lines, on the server)
- Baseline sim cycle count: `59,560` (see `BASELINE.md`)
- Source file analyzed: `software/main.c` (202 lines)
