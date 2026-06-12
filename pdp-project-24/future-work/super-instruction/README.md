# Super-Instruction (fused AES op) — future-work snapshot

**Status: work in progress, NOT integrated into the build.** This folder is a
read-only snapshot, kept so the work is not lost. Nothing here is compiled or
synthesised by the project build (Vivado adds sources with
`add_files -norecurse ./src/design/riscy/`, so this `future-work/` tree is
ignored).

## What it is

Vishnu Karthik's (`kaarviii1`) custom AES "super-instruction": a fused operation
under a custom opcode that does several chained `aes32esmi` lanes in one
instruction (the 4-wide evolution of the 2-lane parallel S-box). It adds a new
hand-written program `software/aes_super.s` and reworks the core datapath
(`cv32e40p_ex_stage.sv`, `cv32e40p_zkne_dom.sv`, `cv32e40p_decoder.sv`,
`cv32e40p_alu.sv`, `cv32e40p_controller.sv`, `cv32e40p_id_stage.sv`,
`include/cv32e40p_pkg.sv`).

## Why it is here and not in main

Team decision, 2026-06-12:

- **Sathya:** "Parallel sbox is fully working latest." → main uses the working
  **parallel DOM S-box** (`cv32e40p_zkne_dom2.sv`).
- **Vishnu:** "Don't merge super Instr branch — that's not working as expected."

The super-instruction and the parallel S-box both rewrite the same EX-stage / DOM
datapath, so they cannot both be the active RTL without a careful integration
(merging the two branches produces 8 conflicts in the core files). Since the
super-instruction does not yet produce correct ciphertext, merging it would risk
breaking the mandatory deliverable (correct AES output). It is therefore kept as
future work rather than wired into the build.

The super-instruction is **not** a mandatory requirement; it is a group-specific
extension presented as future work.

## How to revive it

The full branch (with history) is preserved on GitHub:

```
branch: super-instruction-work-in-progress
commit: f71384d "super-instruction-work-in-progress"
```

The files in this folder are that branch's versions of everything it changed,
mirrored under their original paths (minus the regenerated `*.coe` build
outputs). To resume: check out the branch, finish the datapath so it passes the
ciphertext check in simulation, then integrate against the current parallel-sbox
main.

## Contents

| Path | Role |
|---|---|
| `software/aes_super.s` | the fused super-instruction program (the core artefact) |
| `hardware/src/design/riscy/cv32e40p_ex_stage.sv` | EX-stage datapath for the fused op |
| `hardware/src/design/riscy/cv32e40p_zkne_dom.sv` | DOM S-box path reworked for the fused op |
| `hardware/src/design/riscy/cv32e40p_decoder.sv`, `cv32e40p_alu.sv`, `cv32e40p_controller.sv`, `cv32e40p_id_stage.sv`, `cv32e40p_register_file_ff.sv`, `cv32e40p_core.sv`, `cv32e40p_zkne.sv`, `include/cv32e40p_pkg.sv` | core wiring for the new opcode |
| `software/Makefile`, `software/link.common.ld` | build setup for `aes_super.s` |
| `software/firmware_disasm.txt`, `hardware/dfx_runtime.txt` | generated reference artefacts |
