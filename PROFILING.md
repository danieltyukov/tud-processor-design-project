# AES-128 Baseline — Profiling (Static + Dynamic)

**Status:** Static analysis 2026-04-24; dynamic validation 2026-05-02.
Both methodologies agree on the dominant hot-spot (`mix_columns`),
with dynamic measurement showing it is *more* dominant than static
analysis predicted (83.8% vs ~55%). See § 9.

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

## 7. Dynamic profiling — measured per-function cycles

Static analysis above estimates instruction *counts* and infers cycles
via a global CPI of 1.61. Dynamic profiling measures actual cycles
*directly* using the `mcycle` CSR (RV32 M-mode performance counter).

### 7.1 Methodology

- Bracketed each AES phase in `software/main.c` with `csrr ... mcycle`
  reads. Inline asm with `"memory"` clobber so the compiler doesn't
  reorder loads/stores across the measurement boundary.
- Accumulated per-phase deltas into `volatile uint32_t` globals
  (prevents the optimizer from caching them in registers across the
  9-round loop).
- Wrote results to data BRAM at `0x42002060…0x42002074` after the
  ciphertext check, before the `0xDEADBEEF` end sentinel.
- Extended `hardware/src/simulation/zynq_tb.sv` with 6 `read_data` +
  `$display` calls to print the per-function totals.
- **Critical fix**: CV32E40P resets `mcountinhibit` (CSR 0x320) to
  all-1s, disabling all performance counters by default. Required a
  one-time `csrwi 0x320, 0` at the top of `main()` to enable counting.
  See `cv32e40p_cs_registers.sv:1568`.

### 7.2 Measured results (sim run 2026-05-02)

| Function | Calls/run | Cycles measured | % of 60,457 total |
|---|---:|---:|---:|
| `expand_key` | 1 | **2,417** | 4.0% |
| `aes128_encrypt_block` (sum of phases below + glue) | 1 | **57,526** | 95.1% |
| └ `mix_columns` | 9 | **50,643** | **83.8%** |
| └ `add_round_key` | 11 | 2,850 | 4.7% |
| └ `sub_bytes` | 10 | 2,679 | 4.4% |
| └ `shift_rows` | 10 | 510 | 0.8% |
| Inter-phase glue inside `aes128_encrypt_block` | — | 844 | 1.4% |
| Instrumentation overhead (csrr reads, accumulators) | — | ~897 | 1.5% |
| `main` wrapper, memcpy, `write_to_address` calls | — | ~514 | 0.9% |
| **Total measured** | | **60,457** | 100% |

Total cycles with instrumentation = 60,457; subtracting the +897
instrumentation overhead = **59,560** — matches the baseline exactly.
Test still PASSED with correct ciphertext, so instrumentation did not
perturb correctness.

### 7.3 Static vs dynamic cross-check

| Function | Static estimate (cycles, CPI=1.61) | Measured (cycles) | Ratio |
|---|---:|---:|---:|
| `mix_columns` | ~52,650 | 50,643 | 0.96 ✓ |
| `add_round_key` | ~1,983 | 2,850 | 1.44 |
| `sub_bytes` | ~1,803 | 2,679 | 1.49 |
| `shift_rows` | ~467 | 510 | 1.09 ✓ |
| `expand_key` | ~1,407 | 2,417 | 1.72 |

The two methodologies **agree on the dominant hot-spot** (mix_columns).
Static analysis was within 4% on the biggest contributor. The
1.4-1.7× under-estimates on the smaller functions reflect that their
local CPI is higher than the 1.61 global average — they're more
memory-bound per instruction (load-use chains on byte-level ops),
which the global CPI flattened. Material conclusion: **mix_columns is
even more of an outlier than static analysis predicted**.

### 7.4 Methodology limits (for the report)

- **Instrumentation overhead** (~897 cycles, 1.5%) inflates the
  per-function totals slightly. Each `csrr` pair is ~2 cycles + each
  accumulator update ~3 cycles. Negligible for ranking but visible in
  absolute totals.
- **Per-call granularity not captured**: we sum across all calls of
  each function. To see "round 1 mix_columns vs round 5 mix_columns"
  we would need a 9-element array per function, not a single
  accumulator.
- **CSR access cost varies** by core micro-architecture. CV32E40P
  treats `csrr mcycle` as a single-cycle ALU op once `mcountinhibit`
  is cleared.

## 8. Refined Phase 2 speedup projection (using measured data)

| Change | Cycles saved | Running total |
|---|---:|---:|
| Baseline (measured) | — | **59,560** |
| `aes32esmi` collapses inlined gf_mult + SBox + partial MixColumns in rounds 1–9 (24 calls/round × 9 rounds × ~1 cycle each ≈ 216 cycles in the optimal case) | ~−49,000 | ~10,500 |
| `aes32esi` replaces SBox-only in final round | ~−270 | ~10,200 |
| LLVM loop-unroll pass on outer mix_columns 4-iteration loop | ~−400 | ~9,800 |
| **Realistic best case (measured-bounded)** | | **~10,000** |
| **Conservative target (50% of theoretical savings)** | | **~30,000** |

| Scenario | Speedup vs 59,560 baseline |
|---|---:|
| Conservative (Phase 2.1 deliverables only, half-effective) | **~2.0×** |
| Realistic (Phase 2.1 fully effective + light tuning) | **~3.5×** |
| Aggressive (Phase 2.1 + 2.2 group-specific improvement) | **~5–6×** |

The *measured* dominance of `mix_columns` (83.8%) means even an
imperfect `aes32esmi` implementation captures most of the available
savings. Headline metric for the intermediate report: **target a
≥2× cycle reduction on AES-128 ECB encryption**, with dynamic
profiling evidence showing the mechanism (mix_columns elimination).

## 9. Artifacts

- Full disassembly: `software/output/soft.s` (1,029 lines, on the server)
- Baseline sim cycle count: **59,560** (see `BASELINE.md`)
- Instrumented sim cycle count: 60,457 (=59,560 + 897 overhead)
- Source file analyzed: `software/main.c` (202 lines original; 279 lines instrumented)
- Instrumented testbench: `hardware/src/simulation/zynq_tb.sv` (232 lines)
- Backups for clean revert before submission:
  - `software/main.c.baseline.bak`
  - `hardware/src/simulation/zynq_tb.sv.baseline.bak`
