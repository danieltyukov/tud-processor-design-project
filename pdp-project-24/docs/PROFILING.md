# AES-128 Baseline Profiling (Static and Dynamic)

Static instruction-count analysis and dynamic cycle measurement of the baseline
AES-128 software implementation (`software/main.c`), compiled with LLVM clang
(`rv32imac_zicsr`, `-Os -O0`, `ilp32` ABI). Both methodologies agree that
`mix_columns` is the dominant hot-spot; dynamic measurement shows it is even
more dominant than static analysis predicted.

## 1. Static instruction counts

| Function | Static instrs |
|---|---:|
| `mix_columns` | 186 |
| `aes128_encrypt_block` | 175 |
| `main` | 61 |
| `expand_key` | 55 |
| `aes128_ecb_encrypt` | 33 |
| `shift_rows` | 29 |
| `gf_mult` | 20 (also inlined in `mix_columns`) |
| `sub_bytes` | 14 |
| `add_round_key` | 13 |
| `memcpy` | 12 |
| `memset` | 8 |

`mix_columns` is the largest function because the compiler inlined all eight
`gf_mult()` calls per column-loop iteration, producing eight back-to-back
12-instruction loops inside the 4-iteration column loop. The final (10th) round
skips `mix_columns` by design, so it contributes cycles in rounds 1 to 9 only.

## 2. Dynamic profiling (measured per-function cycles)

Dynamic profiling measures actual cycles directly using the `mcycle` CSR
(RV32 M-mode performance counter). Each AES phase in `main.c` is bracketed by
`csrr mcycle` reads with a `"memory"` clobber so the compiler does not reorder
loads/stores across the boundary; per-phase deltas accumulate into `volatile`
globals.

Note: CV32E40P resets `mcountinhibit` (CSR 0x320) to all-1s, disabling all
performance counters by default. A one-time `csrwi 0x320, 0` at the top of
`main()` is required to enable counting.

| Function | Calls/run | Cycles | % of total |
|---|---:|---:|---:|
| `mix_columns` | 9 | 50,643 | 83.8% |
| `add_round_key` | 11 | 2,850 | 4.7% |
| `sub_bytes` | 10 | 2,679 | 4.4% |
| `expand_key` | 1 | 2,417 | 4.0% |
| `shift_rows` | 10 | 510 | 0.8% |

`mix_columns` dominates by an order of magnitude over every other AES phase.
Static and dynamic methods agree on the dominant hot-spot, with static analysis
landing within about 4% on the biggest contributor.

## 3. Methodology limits

- **Instrumentation overhead** (~1.5%) inflates per-function totals slightly.
  Each `csrr` pair is ~2 cycles and each accumulator update ~3 cycles;
  negligible for ranking but visible in absolute totals.
- **Per-call granularity not captured:** results are summed across all calls of
  each function, so per-round differences are not resolved.
- **CSR access cost varies** by core micro-architecture. CV32E40P treats
  `csrr mcycle` as a single-cycle ALU op once `mcountinhibit` is cleared.

## 4. Implication for Phase 2

The RISC-V Zkne `aes32esmi` instruction performs, in one cycle, the S-box,
partial MixColumns multiply, rotate, and XOR with `rs1`: exactly the body of one
inlined `gf_mult` invocation plus the surrounding S-box and XOR. Replacing this
sequence with a single instruction targets the 83.8% of cycles spent in
`mix_columns`, so even an imperfect implementation captures most of the
available savings. The LLVM loop-unroll pass is orthogonal, removing the outer
4-iteration column-loop overhead.

Headline target: a 2x or greater cycle reduction on AES-128 ECB encryption, with
dynamic profiling evidence showing the mechanism (`mix_columns` elimination).
