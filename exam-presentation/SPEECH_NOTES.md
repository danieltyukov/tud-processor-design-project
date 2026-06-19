# Speaker notes - Processor Design Project, Group 24

Final presentation, 18-06-2026. Deck: `PDP_group24_Final.pdf` (29 slides). First person, written to read aloud.

**Your slides: 8, 9, 10, 11** (marked [YOU]). Deep notes below. The rest are written so any teammate can read them straight.

The one-line story to keep returning to: software AES is slow because of MixColumns; one hardware instruction deletes that bottleneck; then a compiler pass and a parallel masked S-box push it lower, and the masking makes it safe against power attacks.

Delivery: one idea per sentence, pause at the periods. The numbers are the argument, so say them slowly. Budget about 45 to 55 seconds on the content slides, less on the title and the "where AES is used" slide.

One number to never get wrong: the software baseline is **61,184 cycles**. Everything is measured against that.

---

## Slide 1 - Title  *(~10s, teammate)*

Good afternoon. We are group 24, and this is our Processor Design Project. Over the next twenty minutes we will take AES from plain software on a RISC-V core down to a hardware-accelerated design that is also protected against power side-channel attacks.

---

## Slide 2 - Introduction  *(~35s, teammate)*

Data security matters across embedded systems, IoT, and communications. Encryption is how we get it, and AES is the global standard. So our goal is simple to state: implement AES acceleration on a RISC-V core, and do it efficiently in hardware.

---

## Slide 3 - Where is AES used?  *(~20s, teammate)*

Quick context for why we picked AES. It is everywhere: HTTPS, Wi-Fi, file and cloud encryption, VPNs, USB drives, smart cards, passports, and a growing number of IoT devices. That last group is the interesting one. Same encryption requirement, almost no power or area to spare. That is the corner we are designing for.

---

## Slide 4 - AES, what it is  *(~45s, teammate)*

A few facts before the results. AES is a symmetric block cipher, so the same key encrypts and decrypts. It works on a 4×4 grid of bytes, 128 bits, called the state. And before we start, the key is expanded into 11 round keys. The diagram on the right is the full structure for encryption and decryption. We will only zoom into encryption.

---

## Slide 5 - AES, how it works  *(~55s, teammate)*

Here is one encryption. You start by XOR-ing the plaintext with round key 0. Then nine middle rounds, each doing four steps. SubBytes substitutes every byte through the S-box. ShiftRows rotates the rows. MixColumns mixes inside each column over GF(2⁸). AddRoundKey XORs in the round key. The final round, round 10, does the same but skips MixColumns. Remember those four steps. The whole project is about collapsing them into one instruction. The red arrows on the diagram are the points where power leaks, which we come back to later.

---

## Slide 6 - Baseline software implementation  *(~45s, teammate)*

This is our starting point. Plain C AES-128 on the unmodified RISCY core. Ordinary loads, stores, XORs, and shifts. The S-box is a lookup table, MixColumns is software Galois-field multiplication, and both read from data memory. No hardware help. It works, and it costs 61,184 cycles per block, with about 4,600 LUTs. Hold onto that cycle count. It is the baseline for everything that follows.

---

## Slide 7 - Baseline bottlenecks  *(~35s, teammate)*

So where do those cycles go? We profiled it, statically and dynamically, and the answer is lopsided. MixColumns alone is 83.8% of the runtime, over 50,000 cycles. Everything else together, AddRoundKey, SubBytes, key expansion, ShiftRows, is under 15%. That decides where we spend effort. Fix MixColumns, or nothing else matters.

---

## Slide 8 - How does hardware help?  *(~55s)* **[YOU]**

This is where the hardware earns its place.

In software, one MixColumns step compiles to a 186-instruction function. Almost all of that is the Galois-field multiply, `gf_mult`, inlined eight times per column and run bit by bit. That is the work we are deleting.

The RISC-V crypto extension gives us one instruction that does it: `aes32esmi`. In a single instruction it does the whole middle-round operation on one byte: SubBytes, ShiftRows, MixColumns, and AddRoundKey. And it runs entirely on registers. There are no table loads from memory for the S-box, and no memory traffic for MixColumns. That matters, because in the software version every byte was paying a two-cycle BRAM read latency on those lookups.

So the picture on the slide is the whole point. The top row is one software round, roughly 186 instructions. The bottom row is `aes32esmi`, one instruction, one byte per cycle. The inner loop that dominated the baseline just disappears.

**If asked "is it really one cycle?":** the unprotected `aes32esmi` is single-cycle in the datapath. The masked version we add later is multi-cycle, and we will get to why.

**If asked what `aes32esi` is:** same idea for the final round, the one without MixColumns. SubBytes plus rotate plus XOR, no column mixing.

---

## Slide 9 - Performance after AES hardware support  *(~45s)* **[YOU]**

And here is what that buys us.

The software baseline was 61,184 cycles. With `aes32esmi` and `aes32esi` doing the round work, the same encryption is 6,260 cycles. That is 9.8 times faster, and the ciphertext is identical. The speed-up comes from one place: we deleted the MixColumns bottleneck that was 83.8% of the runtime.

So 6,260 is our new starting line. The rest of the talk is two optimizations measured against that number. A custom compiler pass takes it to 4,800. A parallel masked S-box in the RTL takes it to 4,104. I will set those up on the next slide.

**If asked why not more than 9.8×:** the round arithmetic is gone, but we still pay for moving the state in and out and for the loop itself. Those two are exactly what the next two optimizations attack.

---

## Slide 10 - Optimization overview  *(~55s)* **[YOU]**

This slide is the map for the second half, so let me walk the chain left to right.

We start at 61,184 cycles in software. The hardware Zkne instructions take us to 6,260, which is the 9.8× we just saw. From there, two more steps. Our custom LLVM loop-unroll pass brings it to 4,800. And the parallel DOM S-box in the RTL brings it to 4,104. End to end that is about 15 times faster than software, and the final design is side-channel hardened.

One thing to be precise about: the 23% and the 34% are both measured against the 6,260 hardware version, not against each other. So the unroll pass is 23% below 6,260, and the parallel DOM S-box lands 34% below 6,260.

The three cards are the three contributions. One, the hardware AES instructions, which is the mandatory part. Two, the custom compiler pass, also mandatory. Three, the parallel DOM S-box, which is our group-specific work, and it is the interesting one because it adds security and still comes out faster. The numbers on card three, correlation dropping from about 0.24 to 0.07 and the leakage t-value dropping below threshold, are from the hardware capture; I will show the matching simulation numbers later.

**If asked how security got faster:** masking normally costs you speed. We bought it back by running two masked S-boxes in parallel. Net result, the protected design is still below the unprotected unrolled one.

---

## Slide 11 - Vulnerabilities to side-channel attacks  *(~55s)* **[YOU]**

Speed is not the whole story, and this slide is why.

The hardware S-box and MixColumns switch a number of bits that depends on the data they process. That switching shows up in the chip's power draw. So the power trace leaks something about the secret byte going through the S-box.

Correlation Power Analysis turns that leak into the key. You take a power trace of the S-box. You guess one key byte, and you predict the power for that guess using the Hamming weight of S-box of plaintext XOR guess. You do that for all 256 guesses and correlate each against the real traces. The correct guess correlates far better than the other 255 and spikes above them. In our simulation, about 100 traces is enough to pull a key byte out of the unprotected core.

The countermeasure is Domain-Oriented Masking, DOM. You split every secret into two random shares, and you only ever recombine them inside registered gates. So no wire, and no glitch, ever carries the true value. The power then correlates with the random shares, not the secret. This follows the TU Delft secure-Zkne paper by Kassimi, Aljuffri, Hamdioui, and Taouil, 2026.

**If asked "100 traces, is that hardware or sim?":** that is the simulation result, and it is the one I can reproduce on demand. The hardware capture is a separate cross-check on the validation slides.

**If asked why glitches matter:** in plain combinational logic a wire can momentarily settle through a value that depends on both shares at once. The register in a DOM gate stops that transient from propagating, which is what makes it first-order secure.

---

## Slide 12 - Compiler pass, what was done  *(~45s, teammate)*

Now the compiler side. We wrote our own LLVM pass to fully unroll the nine-round AES loop. Instead of flipping a built-in flag, it calls LLVM's unroll routine directly and flattens all nine rounds into straight-line code. It finds the right loop by spotting our AES instructions inside it, so it still fires after inlining. The before-and-after on the right is the idea: a loop body that repeats, turned into nine blocks with no counter and no branch.

---

## Slide 13 - Compiler pass, why  *(~40s, teammate)*

Why write a pass instead of just using `-funroll-loops`? Two reasons. The looped version pays overhead every round: the counter, the branch, the condition check, and the key-pointer reload. And the built-in unroller is cost-model driven, so it often refuses, especially at `-Os`. We wanted to force unrolling on exactly this one loop. And honestly, the point of the exercise was to build the optimization ourselves, not flip a switch.

---

## Slide 14 - Compiler pass, results  *(~40s, teammate)*

The results line up with that. The looped hardware build was 6,260 cycles. A source pragma barely helps, 3%. The built-in `-funroll-loops` gets 12%. Our custom pass reaches 4,800, which is 23% faster, and the ciphertext is still correct. The difference is that our pass guarantees the loop is always fully unrolled, regardless of the cost model.

---

## Slide 15 - Secure AES implementation, the datapath  *(~50s, teammate)*

This is how masking actually sits in the instruction. The original instruction is `aes32esmi rd, rs1, rs2, bs`. Under the secure version, every operand goes in as two shares. We XOR `rs1` with a fresh random number to make share 0, and the random number itself is share 1. Same for `rs2`. The two shares then flow through a shared S-box and a shared MixColumns, and only at the very end are the rotated shares XORed back into `rd`. The fresh randomness is what keeps the shares independent of the real value. This diagram is from the Kassimi 2026 paper that we followed.

---

## Slide 16 - Secure AES implementation, inside the S-box  *(~40s, teammate)*

A closer look at the masked S-box itself. The byte goes through a top linear layer, then a shared non-linear middle layer, then a bottom linear layer. The linear layers are cheap and need no protection. The non-linear middle is the only part that can leak, so that is where the masking and the registers live. This is the tower-field construction: the S-box is rewritten so the only hard part is a small inverse, and that inverse is what we mask.

---

## Slide 17 - RTL optimization, parallel DOM S-box, what  *(~50s, teammate)*

This is our group-specific contribution. We built a custom instruction that runs two DOM-protected S-boxes side by side. Each instruction now processes two byte-lanes of a column instead of one. That meant a new execution unit in the core with two S-boxes in parallel, plus decoder and pipeline changes. Software just XORs the two halves to finish a column. And we kept the original single S-box path intact as a fallback.

---

## Slide 18 - RTL optimization, parallel DOM S-box, why  *(~45s, teammate)*

Why this specifically? Because once the round arithmetic is in hardware, the masked S-box becomes the new bottleneck. DOM is secure, but every byte pays a fixed five-cycle latency and stalls the pipeline. The original design did one byte at a time, so the 16 bytes in a round ran fully serial. Running two S-boxes at once roughly halves the instructions per round. The hard constraint was that the masking had to stay completely intact. A faster S-box that leaks is worthless.

---

## Slide 19 - RTL optimization, results  *(~45s, teammate)*

And it works. From the hardware version at 6,260, the unroll pass took us to 4,800, and the parallel DOM S-box takes us to 4,104. That is 34% faster than the hardware baseline, and it is the version that carries the side-channel protection. The honest cost is area. LUTs go from about 4,600 in the software baseline to nearly 12,000 here, because we now carry two masked S-boxes and a wider datapath. For a security feature, that is a trade we would rather state plainly than hide.

---

## Slide 20 - Validation framework, simulation power analysis  *(~50s, teammate or YOU if you take SCA Q&A)*

So how do we know the masking actually protects anything? This is the validation rig. We take the RTL S-box, unprotected or DOM, and run it in a Vivado xsim testbench that logs a power proxy for every trace: the Hamming weight of the captured S-box result. That goes to a CSV, then into Python for two analyses. CPA correlates power against the Hamming weight of S-box of plaintext XOR guess, over all 256 guesses and 20,000 traces. TVLA runs a Welch fixed-versus-random t-test on 40,000 traces, where a t-value above 4.5 means first-order leakage. Simulation is the right tool here because it isolates the data-dependent switching with no analog noise. A teammate also captured real traces on a CW305 board as an independent cross-check.

---

## Slide 21 - Validation results, DOM defeats the attack  *(~55s, teammate or YOU)*

This is the payoff in simulation. Same rig, same injected noise, sigma 2.0. The only thing that changes is the S-box.

On the left, TVLA. The unprotected core climbs to a t-value of 44, far over the 4.5 threshold, and it crosses after a few hundred traces. The DOM version stays flat at 1.4 and never crosses. On the right, CPA. Against the unprotected core the true key is rank 1 with correlation 0.58. With masking, the true key drops to rank 35 and correlation 0.02, buried in the noise. So masking takes a key that falls in about 100 traces and makes it unrecoverable, and the speed-up still holds.

---

## Slide 22 - Hardware validation, CW305 setup  *(~40s, teammate)*

From simulation to silicon. A teammate ran the same kind of attack on a real board: a CW305 with an Artix-7 100T carrying the CV32E40P core, a ChipWhisperer-Lite scope at 50 MHz, ADC at 200 MHz, 30 dB gain. Three bitstreams were tested: a reference AES, the baseline RISCY, and the DOM-protected RISCY. The attack is the same CPA and TVLA, in a window around the round-1 S-box, same 4.5 threshold.

---

## Slide 23 - Hardware validation results  *(~45s, teammate)*

On hardware, CPA breaks the unprotected reference AES, 16 of 16 bytes, correlation 0.236. With DOM, correlation drops to 0.07, the noise floor, and no bytes come out. TVLA tells the same story: 49 on the unprotected reference, down to 3.98 with DOM, below threshold. So real silicon agrees with the simulation: DOM removes the first-order leakage.

**Honesty note if pressed:** the strong, fully reproducible result in this project is the simulation. On the committed hardware traces, the unprotected RISCY core did not cleanly recover under a textbook CPA, which is the kind of thing that happens with a noisy software-driven capture. Present the simulation as the proof, and the hardware as a supporting cross-check. Do not claim the two corroborate each other number for number.

---

## Slide 24 - Hardware validation, TVLA traces  *(~40s, teammate)*

The three TVLA traces, top to bottom. The unprotected reference AES spikes to 49, about ten times the threshold, with clear data-dependent leakage. The baseline RISCY barely touches the line, one marginal sample. The DOM-protected core stays under 4.5 the whole way, zero leaking samples. Conclusion: DOM eliminates first-order leakage on real silicon, consistent with what we saw in simulation.

---

## Slide 25 - Future work, the observation  *(~35s, teammate)*

Where we would go next. Look at one AES round in our code: it is the same `aes32esmi` four times, once per byte lane, because a register is 32 bits and a byte is 8. Four near-identical instructions, fetched and decoded separately, for one round. They are independent and perfectly regular. That regularity is overhead, and it puts a ceiling on throughput.

---

## Slide 26 - Future work, the super-instruction  *(~40s, teammate)*

So the idea is a super-instruction. Replicate the Zkne datapath four times, run all four lanes in parallel inside one instruction, combine the results internally with an XOR tree, and write back one 32-bit result. One fetch, one decode, a whole column's worth of work. The block diagram on the right is the proposal: four Zkne modules feeding one XOR.

---

## Slide 27 - Future work, architectural changes  *(~35s, teammate)*

What it would take. A new opcode and instruction format, shown here with four source-register fields. Changes to the register file or decode logic to read four sources. Replicating the Zkne hardware four times. And software support to emit the new instruction. We have the design and a draft datapath, but it does not yet produce correct ciphertext, so we are presenting it as future work rather than a result.

---

## Slide 28 - Future work, limitations  *(~35s, teammate)*

And we are honest about the costs. It pollutes the custom-0 opcode space, which is scarce and could clash with future standard extensions. Reading four source registers needs extra read ports or a two-cycle read, which complicates the pipeline. Replicating the datapath four times costs real LUTs and flip-flops. And it only helps AES; that area sits idle for any other workload. Those four are exactly why it is future work and not in the shipped core.

---

## Slide 29 - Thank you  *(~10s, teammate)*

That is our project: AES from software to hardware, 15 times faster, and hardened against power attacks. Thank you. Happy to take questions.

---

## Quick-reference numbers (for Q&A)

- Software baseline: **61,184 cycles**, ~4,644 LUTs.
- MixColumns share of baseline runtime: **83.8%** (~50,643 cycles).
- Software `mix_columns`: **186** compiled instructions.
- Hardware Zkne (`aes32esmi`/`aes32esi`): **6,260 cycles, 9.8×**.
- Custom LLVM unroll pass: **4,800 cycles, −23%** vs 6,260.
- Parallel DOM S-box: **4,104 cycles, −34%** vs 6,260; ~11,987 LUTs.
- End to end: **~15× faster** than software.
- DOM S-box per-byte latency: **5 cycles**; randomness ~20 bits per S-box.
- Side-channel, simulation: unprotected CPA rank 1, |r| 0.58, ~100 traces, TVLA |t| 44; DOM rank 35, |r| 0.022, TVLA |t| 1.4.
- Side-channel, hardware (cross-check): unprotected CPA |r| 0.236, TVLA |t| 49; DOM |r| 0.07, TVLA |t| 3.98.
- Reference: Kassimi, Aljuffri, Larmann, Hamdioui, Taouil, *Secure Implementation of RISC-V's Scalar Cryptography Extension Set*, Cryptography 10(1):6, 2026.

**Sim vs hardware rule:** the reproducible proof of "DOM defeats the attack" is the simulation rig. The hardware capture is a cross-check, not a number-for-number match. Never present one as confirming the other exactly.
