# Processor Design Project — Group 24 (CESE4040, TU Delft)

> **Context for the exam Q&A.** This folder holds the final presentation
> (`PDP_group24_Final.pdf`, 29 slides). The notes below let an interview/exam
> copilot answer, in the first person, any question about *what we built, why,
> and the numbers* — including questions tied to a specific slide number.
> The companion file **`ARCHITECTURE.md`** has the slide-by-slide map (slides
> 1–29) and the deep technical detail. Read both.

I am **Daniel**, presenting with Group 24. Project repo:
`github.com/danieltyukov/tud-processor-design-project` (submission lives in
`pdp-project-24/`). Date on the deck: 18-6-2026.

## The one-line story
We took **AES-128 from plain C software on a RISC-V core down to a
hardware-accelerated, side-channel-protected design**, and then made it faster
two more ways. *Software is slow because of MixColumns; hardware fixes that; then
a compiler pass and a parallel masked S-box make it faster while staying secure.*

## The four numbers (memorise these — slide 10 "Optimization Overview")
| Stage | Cycles/block | Change | What changed |
|---|---:|---|---|
| Software AES baseline | **61,184** | 1.0× | Pure C on the unmodified core |
| + HW AES (Zkne) | **6,260** | **9.8× faster** | `aes32esmi`/`aes32esi` instructions |
| + custom LLVM unroll pass | **4,800** | −23% (vs 6,260) | Fully unroll the 9-round loop |
| + parallel DOM S-box (RTL) | **4,104** | −34% (vs 6,260) | Two masked S-boxes per instruction |

Overall **≈15× faster than the software baseline, and side-channel hardened**.
"6,260 is the new starting line" — both later optimisations are measured against
it, not against 61,184.

## What we actually built (the deliverables)
1. **Profiled the software baseline** — found MixColumns is **83.8%** of all
   cycles (50,643 of 61,184). That single fact drove every later decision.
2. **Hardware AES (RISC-V Zkne scalar-crypto extension)** — `aes32esmi` fuses
   SubBytes + ShiftRows + MixColumns + AddRoundKey into one register-only
   instruction, deleting the MixColumns bottleneck. → 6,260 cycles.
3. **Custom LLVM loop-unroll pass** (`AESUnroll.cpp` → `libAESUnroll.so`) —
   fully unrolls the 9-round AES loop at compile time. → 4,800 cycles. *(Hruday)*
4. **Parallel DOM S-box (RTL)** — a custom instruction running **two
   Domain-Oriented-Masking-protected S-boxes side by side**, halving S-box
   instructions per round while keeping first-order side-channel protection.
   → 4,104 cycles. *(Sathya led the RTL; this is our group-specific contribution)*
5. **Side-channel validation framework** — my main contribution: a simulation
   rig (Vivado xsim testbench + Python CPA/TVLA) that proves the masking works,
   plus a real-silicon cross-check on a CW305 board. *(simulation: me; CW305: Rishi)*

## Why these choices (defend them)
- **Why hardware AES at all?** MixColumns in software is ~186 instructions of
  Galois-field multiply per round, all from data memory. The Zkne instruction
  does it on registers in one cycle. Fixing the 83.8% bottleneck is the only
  thing that moves the needle.
- **Why write our own unroll pass instead of `-funroll-loops`?** The built-in
  unroller is cost-model driven and *refuses* to unroll at `-Os`; a source
  `#pragma` only bought 3%. Our pass calls LLVM's `UnrollLoop()` directly and
  *guarantees* the loop is always fully unrolled. The point was to build the
  optimisation, not flip a switch.
- **Why masking (DOM)?** The hardware S-box switches a data-dependent number of
  bits, so power leaks the secret byte. CPA recovers a key byte in ~100 traces
  on the unprotected core. DOM splits every secret into two random shares,
  recombined only inside registered gates, so no wire (and no glitch) ever
  carries the true value.
- **Why a *parallel* DOM S-box?** Once masking is on, the DOM S-box is the new
  bottleneck: every byte pays a fixed **5-cycle** latency and stalls the
  pipeline, and the original design did one byte at a time (16 bytes/round,
  fully serial). Running two lanes at once halves the S-box ops per round. Hard
  constraint: the masking had to stay *completely* intact — a faster S-box that
  leaks is worthless.
- **Honest cost: area.** LUTs go from ~4,644 (software baseline) to ~11,987
  (parallel DOM design) — we now carry two masked S-boxes and a wider datapath.
  For a security feature, I'd rather state that trade plainly than hide it.

## Validation result I'm proudest of (slides 20–24)
Same rig, same injected noise (σ = 2.0), only the S-box changes:
- **TVLA** (leakage test, threshold |t| = 4.5): unprotected Zkne climbs to
  **|t| = 44**; DOM-masked stays flat at **|t| = 1.4** and never crosses.
- **CPA** (key recovery): unprotected → true key is **rank 1/256, |r| = 0.58**;
  DOM-masked → true key drops to **rank 35/256, |r| = 0.02**, buried in noise.
- **Real silicon (CW305)** confirms it: DOM brings TVLA |t| to **3.98** (below
  4.5) and CPA correlation to the noise floor (**0.07**).

So masking takes a key that falls in ~100 traces and makes it unrecoverable —
and the speed-up still holds.

## Honesty caveats (have these ready)
- The **reproducible, clean before/after is the *simulation*** (xsim + Python).
  It isolates data-dependent switching with no analog noise.
- On the **CW305 hardware**, full key recovery succeeded only on the **AES_100t
  reference** design (which validates the measurement setup). On *our* cores CPA
  did **not** fully recover the key within the captured traces — different
  platform, more noise. The honest claim is: leakage is *measurable* on the
  unprotected designs (PGE drops), and DOM pushes TVLA below threshold. I do not
  claim sim and hardware corroborate each other one-to-one.
- The **super-instruction** (4-wide fused AES op, slides 25–28) is **future
  work, not built** — it does not yet produce correct ciphertext, so the active
  core ships the working 2-lane parallel DOM S-box.

## Team & ownership (Group 24)
- **Daniel (me):** side-channel/security track — DOM-masked tower-field S-box
  algebra, the simulation-based CPA/TVLA validation framework, the security
  narrative. **I present slides 8–11** (how hardware helps, performance after HW,
  optimization overview, side-channel vulnerability) and own the side-channel /
  validation Q&A (slides 20–24). See `SPEECH_NOTES.md` for my per-slide script
  and "if asked…" defenses.
- **Hruday:** custom LLVM loop-unroll pass (compiler, mandatory milestone M4).
- **Sathya:** parallel DOM S-box RTL (`cv32e40p_zkne_dom2.sv`, new EX unit).
- **Rishi:** CW305 ChipWhisperer hardware capture and CPA/TVLA on real silicon.

## Platform facts (quick reference)
- **Core:** CV32E40P (a.k.a. RI5CY / "RISCY"), a 4-stage 32-bit RISC-V core.
- **ISA/ABI:** `rv32imac_zicsr`, `ilp32`. Crypto = RISC-V **Zkne** scalar
  extension (`aes32esmi` middle round, `aes32esi` final round / no MixColumns).
- **FPGA:** PYNQ-Z1 `xc7z020clg400-1` (OOC area/timing estimated on `xc7z010`);
  hardware SCA on the **CW305 Artix-7 XC7A100T**. Tools: Vivado 2024.2,
  LLVM/Clang + riscv-gcc, ChipWhisperer-Lite + Python (numpy/scipy/matplotlib).
- **Baseline correctness:** ciphertext `fba50914 714bf41f 2e25aabe aaf9080f`,
  test PASSED; end sentinel `0xDEADBEEF` at `0x2000`.

See `ARCHITECTURE.md` for the per-slide breakdown and the DOM/CPA/TVLA internals.
