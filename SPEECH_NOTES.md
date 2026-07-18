# Speaker Notes — Processor Design Project, Group 24

Final presentation, 12-06-2026. 20-minute slot. Notes are first-person, written to be read aloud.

**Speaker split (per the team agreement):** Daniel presents slides 8-10 and 14-18 (marked **[YOU]**). The rest are teammates' sections, written so whoever takes them can read them straight.

**Delivery:**
- One idea per sentence. Pause at the periods.
- Numbers are the argument. Say them slowly: "sixty-one thousand", "six thousand two hundred sixty".
- The whole story is one line: software is slow because of MixColumns, hardware fixes that, then we make it faster and safe. Keep coming back to it.
- Budget ~45-55 seconds per content slide, less on the title and the AES-uses slide. That leaves room for the demo and questions.

---

## Slide 1 — Title  *(~10s, teammate)*

Good afternoon. We're group 24. This is our Processor Design Project. Over the next twenty minutes I'll show how we took AES from plain software on a RISC-V core down to a hardware-accelerated design that's also protected against power attacks.

---

## Slide 2 — Introduction  *(~40s, teammate)*

AES is the encryption behind almost everything we trust online: web traffic, Wi-Fi, disk encryption. So making it fast on small devices matters. Our goal was simple to state. Run AES-128 on a RISC-V core, then make it faster in hardware without breaking its security.

---

## Slide 3 — Where is AES used?  *(~25s, teammate)*

Quick context for why AES. It's everywhere. HTTPS, Wi-Fi, VPNs, file and disk encryption, smart cards, passports, and more and more tiny IoT devices. That last group is the interesting one. They need the same encryption but have almost no power or area to spare. That's the problem we're solving.

---

## Slide 4 — Advanced Encryption Standard (what)  *(~50s, teammate)*

A few facts before the results. AES is a symmetric block cipher, so the same key encrypts and decrypts. It works on a 4×4 grid of bytes, 128 bits, that we call the state. And the key gets expanded into eleven round keys before we start. The diagram on the right is the full structure. I'll only zoom into the encryption side.

---

## Slide 5 — Advanced Encryption Standard (how)  *(~60s, teammate)*

Here's one encryption. You start by XOR-ing the plaintext with the first round key. Then nine middle rounds, each doing four steps. SubBytes substitutes every byte through the S-box. ShiftRows rotates the rows. MixColumns mixes inside each column over GF(2⁸). AddRoundKey XORs in the round key. The final round does the same but skips MixColumns. Remember those four steps. The whole project is about collapsing them.

---

## Slide 6 — Baseline software implementation  *(~45s, teammate)*

This is our starting point. Plain C AES-128 on the unmodified RISCY core. Everything is ordinary loads, stores, XORs and shifts. The S-box is a lookup table, MixColumns is software Galois-field multiplication, all read from data memory. No hardware help. It works, and it costs 61,184 cycles per block. Hold onto that number. It's the baseline everything else is measured against.

---

## Slide 7 — Baseline bottlenecks  *(~40s, teammate)*

So where do those cycles go? We profiled it, and the answer is lopsided. MixColumns alone is 83.8% of the runtime, over 50,000 cycles. Everything else together, the S-box, key expansion, AddRoundKey, ShiftRows, is under 15%. That tells us where to spend effort. Fix MixColumns or nothing else matters.

---

## Slide 8 — How does hardware help?  *(~50s)* **[YOU]**

This is where the hardware comes in. In software, one MixColumns step is about 186 instructions of Galois-field multiply. The RISC-V crypto extension gives us one instruction, aes32esmi, that does SubBytes, ShiftRows, MixColumns and AddRoundKey for a byte in a single cycle. It runs entirely on registers, with no table loads from memory. So that 186-instruction inner loop collapses into a handful of instructions.

---

## Slide 9 — Performance after AES hardware support  *(~45s)* **[YOU]**

And here's what that buys us. The software baseline was 61,184 cycles. With the aes32esmi and aes32esi instructions, the same encryption is 6,260 cycles. That's 9.8 times faster, and it comes from deleting the MixColumns bottleneck. So 6,260 is our new starting line. The rest of the talk is two optimisations that push it lower. A compiler pass takes it to 4,800, and a parallel masked S-box takes it to 4,104.

---

## Slide 10 — Vulnerabilities to side-channel attacks  *(~55s)* **[YOU]**

But speed isn't the whole story. The hardware S-box switches a number of bits that depends on the data, and that shows up in the chip's power draw. Correlation Power Analysis exploits exactly that. You guess one key byte, predict its power, and correlate against real traces. The correct guess spikes above the other 255. In our simulation, about a hundred traces is enough to pull a key byte out of the unprotected core.

The countermeasure is Domain-Oriented Masking, or DOM. You split every secret into two random shares, and only recombine them inside registered gates. So no wire, and no glitch, ever carries the true value. This follows the TU Delft secure-Zkne paper by Kassimi, Aljuffri, Hamdioui and Taouil.

---

## Slide 11 — Compiler optimisation: custom LoopUnroll pass (what)  *(~45s, teammate)*

Now the compiler side. We wrote our own LLVM pass to fully unroll the nine-round AES loop. Instead of flipping a built-in flag, it calls LLVM's unroll routine directly and flattens all nine rounds into straight-line code. It finds the right loop by spotting our AES instructions inside it, so it still fires after inlining.

---

## Slide 12 — Compiler optimisation: custom LoopUnroll pass (why)  *(~40s, teammate)*

Why write a pass instead of just using -funroll-loops? Two reasons. The looped version pays overhead every round: the counter, the branch, the condition check, the key-pointer reload. And the built-in unroller is cost-model driven, so it often refuses, especially at -Os. We wanted to force unrolling on exactly this loop. The point of the exercise was to build the optimisation ourselves, not flip a switch.

---

## Slide 13 — Compiler optimisation: results  *(~40s, teammate)*

The results line up. The looped hardware version was 6,260 cycles. A source pragma barely helps, 3%. The built-in -funroll-loops gets 12%. Our custom pass reaches 4,800, 23% faster, and the ciphertext is still correct. The difference is that our pass guarantees the loop is always fully unrolled.

---

## Slide 14 — RTL optimisation: parallel DOM S-box (what)  *(~50s)* **[YOU]**

Back to hardware, and this is our group-specific contribution. We built a custom instruction that runs two DOM-protected S-boxes side by side. Each instruction now processes two byte-lanes of a column instead of one. That meant a new execution unit in the core, two S-boxes in parallel, plus decoder and pipeline changes. Software just XORs the two halves to finish a column. And we kept the original single S-box path as a fallback.

---

## Slide 15 — RTL optimisation: parallel DOM S-box (why)  *(~45s)* **[YOU]**

Why this specifically? Because the masked S-box is now the bottleneck. DOM adds protection, but every byte pays a fixed five-cycle latency and stalls the pipeline. The original design did one byte at a time, so the sixteen bytes in a round ran fully serial. Running two S-boxes at once halves the instructions per round. The hard constraint was that the masking had to stay completely intact. A faster S-box that leaks is worthless.

---

## Slide 16 — RTL optimisation: results  *(~45s)* **[YOU]**

And it works. From the looped hardware version at 6,260, the unroll pass took us to 4,800, and the parallel DOM S-box takes us to 4,104. That's 34% faster than where we started. The honest cost is area. LUTs go from about 4,600 in the software baseline to nearly 12,000 here, because we're now carrying two masked S-boxes and a wider datapath. For a security feature, that's a trade I'd rather state plainly than hide.

---

## Slide 17 — Validation framework: simulation-based power analysis  *(~55s)* **[YOU]**

So how do we know the masking actually protects anything? This is the validation rig I built. I take the RTL S-box, unprotected or DOM, and run it in a Vivado xsim testbench that logs a power proxy for every trace, the Hamming weight of the S-box result. That goes to a CSV, then into Python for two analyses. CPA correlates power against the Hamming weight of S-box of plaintext XOR guess, over all 256 guesses and 20,000 traces. TVLA runs a Welch fixed-versus-random t-test on 40,000 traces, where a t-value above 4.5 means first-order leakage. Simulation is the right tool here because it isolates the data-dependent switching with no analog noise. A teammate also captured real traces on a CW305 board as an independent cross-check.

> **[If asked about the hardware]** The reproducible result is the simulation. The hardware capture confirmed the traces are genuine AES under the known key, but on the committed dataset a standard CPA did not recover the key, different platform, different noise. I'm not claiming the two corroborate each other. The leakage-before-and-after result I'm showing is the simulation.

---

## Slide 18 — Validation results: DOM defeats the attack  *(~55s)* **[YOU]**

And this is the payoff. Same rig, same injected noise, sigma 2.0. The only thing I change is the S-box. On the left, TVLA. The unprotected core climbs to a t-value of 44, far over the 4.5 threshold, and it crosses after a few hundred traces. The DOM version stays flat at 1.4 and never crosses. On the right, CPA. Against the unprotected core the true key is rank 1, correlation 0.58. With masking, the true key drops to rank 35 and correlation 0.02, buried in the noise. So masking takes a key that falls in a hundred traces and makes it unrecoverable, and the speed-up still holds. That's the result I'm most proud of.

---

*Numbers cross-checked against the deck (`PDP_group24.pdf`) and `sca_results/VERIFICATION.md`. The sim figures on 17-18 are reproducible from the `sidechannel/` rig; the CW305 hardware figures are not committed, so they stay a cross-check, never a corroboration.*
