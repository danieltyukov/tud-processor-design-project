# Super-instruction (fused AES op): future-work snapshot

This folder is a read-only snapshot of an in-progress design, kept for reference.
Nothing here is compiled or synthesised: the project build adds RTL with
`add_files -norecurse ./src/design/riscy/`, so this `future-work/` tree is ignored.

## What it is

A custom AES super-instruction: a fused operation under a custom opcode that
performs several chained `aes32esmi` lanes in one instruction (a 4-wide
evolution of the 2-lane parallel S-box). It adds a hand-written program
`software/aes_super.s` and reworks the core datapath (`cv32e40p_ex_stage.sv`,
`cv32e40p_zkne_dom.sv`, `cv32e40p_decoder.sv`, `cv32e40p_alu.sv`,
`cv32e40p_controller.sv`, `cv32e40p_id_stage.sv`, `include/cv32e40p_pkg.sv`).

## Why it is future work, not in the build

The super-instruction is not a mandatory deliverable; it is a group-specific
extension. It and the parallel DOM S-box both rewrite the same EX-stage and DOM
datapath, so they cannot both be active without a careful integration. The
super-instruction does not yet produce correct ciphertext, so the active core
uses the working parallel DOM S-box (`cv32e40p_zkne_dom2.sv`) and this design is
documented as future work. To resume it: finish the datapath so it passes the
ciphertext check in simulation, then integrate it against the current core.

## Contents

| Path | Role |
|---|---|
| `software/aes_super.s` | the fused super-instruction program |
| `hardware/src/design/riscy/cv32e40p_ex_stage.sv` | EX-stage datapath for the fused op |
| `hardware/src/design/riscy/cv32e40p_zkne_dom.sv` | DOM S-box path reworked for the fused op |
| core wiring (`cv32e40p_decoder.sv`, `cv32e40p_alu.sv`, `cv32e40p_controller.sv`, `cv32e40p_id_stage.sv`, `cv32e40p_register_file_ff.sv`, `cv32e40p_core.sv`, `cv32e40p_zkne.sv`, `include/cv32e40p_pkg.sv`) | new-opcode wiring |
| `software/Makefile`, `software/link.common.ld` | build setup for `aes_super.s` |
| `software/firmware_disasm.txt`, `hardware/dfx_runtime.txt` | generated reference artefacts |
