# Intermediate Report: Final Answers

CESE4040 Processor Design Project, Q4 2025-2026, Group 24.

Group members: Daniel Tyukov, Rishi, Vishnu Karthik, Hruday Gowda, Sathya.

---

## Q1. What extension(s) and improvement(s) are you planning to implement?

The mandatory deliverables are the Zkne instructions `aes32esi` and `aes32esmi` in the CV32E40P ALU and decoder, plus a built-in LLVM loop-unroll pass on the AES middle-round loop. On top of these we propose two candidate group-specific improvements and will commit to one after consultation with the project supervisors.

**Option 1: Prevention of side-channel attack**

Making the `aes32esmi` implementation resilient to power side-channel attacks through Domain-Oriented Masking of the instruction datapath, so that no intermediate value in the hardware exposes key-dependent switching activity. This contribution is based on the work of Kassimi et al. in "Secure Implementation of RISC-V's Scalar Cryptography Extension Set."

**Option 2: Custom instruction to execute multiple AES operations per instruction**

The Zkne `aes32esmi` instruction does exactly one byte's worth of work: one S-box, one partial MixColumns, one XOR. Computing one full output word requires four chained `aes32esmi` instructions, and a complete middle round needs sixteen of them. We plan to collapse each four-instruction chain into a single instruction that computes one full output word in one cycle. It takes the four state words as inputs and produces one output word directly.

A final decision between the two candidates will be made following consultation with the project supervisors and an assessment of implementation feasibility within the remaining project timeline.

---

## Q2. What metrics will be used to evaluate the final design?

**Option 1**

The proposed side-channel-resilient design is planned to be validated using a multi-layer evaluation methodology combining formal verification, statistical leakage assessment, and practical attack analysis. Formal security verification is performed using tools like SILVER to assess probing and glitch-resistant security properties at the hardware level. Experimental leakage evaluation is conducted using Test Vector Leakage Assessment (TVLA), while practical resistance against power-analysis attacks is assessed through CPA and key-rank analysis. Together, these methods provide both theoretical and empirical validation of the design's side-channel resilience.

To generate the power traces, two possible approaches can be considered. First, power traces may be estimated from generated `.vcd` files using the Hamming-distance leakage model, after which side-channel attacks can be performed in software. Alternatively, subject to approval and availability of the laboratory setup, empirical power traces may be collected using a hardware measurement setup, as reportedly arranged for previous projects.

**Option 2**

Reduction in latency beyond the mandatory `aes32esi`/`aes32esmi` deliverables. We plan to compare the cycle count of the baseline (59,560 cycles), the `aes32esi`/`aes32esmi` implementation, and the custom instruction. We also plan to measure area to check for possible savings or expenditure in silicon. Functional correctness is verified every run by checking the produced ciphertext against the expected output `fba50914 714bf41f 2e25aabe aaf9080f`.

---

## Q3. Why have you chosen for these extension(s) / improvement(s)?

**Option 1**

Side-channel resilience is essential because cryptographic hardware can leak sensitive information through physical effects such as power consumption, timing variations, or electromagnetic emissions, even when the underlying cryptographic algorithm is mathematically secure. Attackers can exploit this unintended leakage using techniques such as Differential Power Analysis (DPA) or Correlation Power Analysis (CPA) to recover secret keys. As hardware accelerators are increasingly deployed in security-critical applications including IoT devices, embedded systems, and secure communication platforms, protecting implementations against side-channel attacks has become a necessary requirement. Incorporating side-channel-resistant design techniques therefore improves the overall security and trustworthiness of the hardware implementation beyond conventional functional correctness.

**Option 2**

The Zkne `aes32esmi` instruction does exactly one byte's worth of work: one S-box, one partial MixColumns, one XOR. Computing one full output word requires four chained `aes32esmi` instructions, and a complete middle round needs sixteen of them. AES and other encryption methods are standard in modern communication systems, and for faster communication, low-latency encryption modules are indispensable.

---

## Q4. Methodology: tasks, ownership, integration / baseline / validation

We split the five of us into three sub-teams (provisional, individuals not yet assigned to specific objectives):

- **RTL team (2 people)**: implement and integrate the required RTL depending on the chosen option.
- **Validation team (2 people)**: set up the validation framework and perform validation. The exact objective changes based on the chosen option.
- **Compiler team (1 person)**: run compiler optimisations including instruction scheduling and loop optimisations.

**A) Integration**

The Zkne instructions `aes32esi` and `aes32esmi` are added to the CV32E40P ALU and decoder. The RTL team handles the SBox and partial-MixColumns network in the ALU. The compiler team exposes them to C through inline asm first, then adds proper LLVM intrinsics once the toolchain is rebuilt in `$HOME` on the server. The compiler team also wires LLVM's `LoopUnrollPass` to the AES middle-round loop. Under Option 1, the validation team adds a DOM-protected variant of the same instructions. Under Option 2, the RTL team adds a custom instruction under the `custom-0` opcode that fuses four chained `aes32esmi` calls into one.

**B) Definition of baseline**

Phase 1 produced the baseline:

- Cycle baseline from behavioural simulation: 59,560 cycles, ciphertext PASSED.
- OOC synthesis (core only): 5,691 LUTs, 2,524 registers, 5 DSPs, WNS +5.513 ns at 100 MHz.
- Post-implementation, full `riscv_wrapper`, routed: 10,171 LUTs, 8,522 registers, 16 BRAMs, 5 DSPs, WNS +28.306 ns at 20 MHz, 1.419 W on-chip power.
- Static profiling: `mix_columns` is 88 % of static instructions.
- Dynamic profiling via `mcycle` brackets: `mix_columns` is 83.8 % of measured cycles.

**C) Validation / measurements**

After every RTL change we re-run the AES simulation, confirm the ciphertext, and record the cycle count against 59,560. We re-run OOC synthesis to capture LUT, register, DSP, and WNS deltas. We generate a fresh bitstream and load it on the PYNQ-Z1 to confirm the wall-clock ciphertext matches simulation. Under Option 1 we additionally run TVLA on the unprotected baseline as a sanity check that the framework detects leakage, then TVLA, CPA, and key-rank on the protected variant. Under Option 2 we benchmark the cycle count of the baseline, the `aes32esi`/`aes32esmi`-only version, and the custom-instruction version, plus an area sweep to check the silicon cost.

---

## Q5. Planning: Gantt chart and milestones

The team's Gantt chart is attached to this question as `2026-05-08-rishi-gantt.png`.

![Gantt chart, 2026-05-08](gantt/2026-05-08-rishi-gantt.png)

Milestones (dates from the Gantt):

- **M1, 2026-05-08.** Intermediate report submitted; Phase 1 closed.
- **M2, 2026-05-14.** Zkne instructions and the loop-unroll pass working in simulation; ciphertext still passes.
- **M3, 2026-05-15.** Bitstream for the mandatory variant generated; first cycle count recorded against 59,560.
- **M3.5, 2026-05-15.** Decision on the group-specific option after TA and Prof. Mottah's feedback.
- **M4, 2026-06-09.** Selected option's RTL and C files in.
- **M5, 2026-06-11.** Final validation. Option 2: cycle count and PYNQ-Z1 board verification. Option 1: TVLA, CPA, and key-rank on the protected design.
- **M6, 2026-06-12.** Source archive submitted, slides ready, demo rehearsed.