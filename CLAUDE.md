# PDP Project — Group 24 (CESE4040, Q4 2025-2026)

This file is the primary working context for the Processor Design Project. It sits in the personal workspace root (one level above the course gitlab repo) so every Claude Code session at this level auto-loads it. The gitlab-tracked sources live in `pdp-project-24/`; our helpers, notes, and the course PDFs live alongside it.

## 0. Workspace layout

```
tud-processor-design-project/                 # workspace root (this file lives here)
├── CLAUDE.md                                 # <- primary project context
├── scripts/                                  # our personal helpers (not committed)
│   ├── _lib.sh                               # shared: sources credentials
│   ├── setup-server-auth.sh                  # one-time: push our SSH pubkey to the server
│   ├── connect-server.sh                     # ssh into the server
│   ├── mount-server.sh                       # sshfs-mount server $HOME at ~/pdp-server-mnt
│   ├── umount-server.sh
│   ├── launch-vivado.sh                      # ssh -Y → run Vivado GUI (or --batch-sim headless)
│   ├── launch-x2go.sh                        # seed x2go session + start client (full MATE desktop)
│   └── fetch-from-server.sh                  # scp files from the server to ./artifacts/
├── pdp-project-24/                           # THE GITLAB REPO — keep clean for submission
│   ├── README.md                             # official course README
│   ├── hardware/ …                           # RISCY RTL + Vivado TCL scripts
│   └── software/ …                           # C AES app + LLVM/GCC Makefile config
├── 01-Introduction.AES.RISCY.updated.pdf     # course PDFs (reference)
├── CESE4040.2026_Kickoff.v1.pdf
├── pdp_course_description (1).pdf
├── pdp_compiler_workflow_manual (1).pdf
└── pdp_server_and_project_manual (1).pdf
```

Credentials are at `~/.config/pdp-project-24/credentials.txt` (chmod 600, **not** in this tree) — single source of truth that every script in `scripts/` sources.

## 1. Who and what

- **Course:** CESE4040 Processor Design Project, TU Delft, Q4 2025-2026.
- **Group:** **24**, team of 4.
- **GitLab remote** (in `pdp-project-24/`): `git@gitlab.ewi.tudelft.nl:qce/computer-engineering/computer-engineering/courses/pdp-processor-design-project/student-work/2025-2026/pdp-project-24.git`
- **Goal:** take a baseline RISCY RISC-V soft core on a Digilent PYNQ-Z1 (Zynq-7000) FPGA running a C software AES-128, profile it, and improve performance through coordinated hardware (RTL) and compiler (LLVM) changes.

## 2. Mandatory deliverables

1. **HW — RISC-V Zkne scalar-crypto instructions in the RISCY core:**
   - `aes32esmi rd, rs1, rs2, bs` — encrypt middle round (SBOX + partial MixColumns + rotate + XOR with `rs1`).
   - `aes32esi  rd, rs1, rs2, bs` — encrypt final round (SBOX + rotate + XOR with `rs1`, no MixColumns).
   - Expose both through the LLVM toolchain so C code can emit them (inline asm first, then a proper builtin/intrinsic if time permits).
2. **Compiler — LLVM built-in loop-unroll pass** applied to the AES middle-round loop (the one using `aes32esmi`), with a before/after measurement.
3. **Group-specific improvement(s)** — chosen from latency, throughput, area, memory footprint, register pressure, side-channel resistance, custom LLVM passes, etc. Must be justified against a measured baseline in the intermediate report.

## 3. Key deadlines (today is 2026-04-24)

| Date | Milestone |
|------|-----------|
| Fri 2026-04-24 | First lab session (already happened, 13:45–17:45, EWI-Tellegen Hall 1/2/3) |
| Mon 2026-05-04 | Brightspace intermediate-report quiz **opens** |
| **Fri 2026-05-08 23:59** | Intermediate report **due** — one submission per group |
| Every Fri 13:45–17:45 | Lab sessions, EWI-Tellegen Hall practicumzalen 1/2/3 |
| Fri 2026-06-12 | End of week 8 — source archive + final presentation slides submitted |
| Weeks 25–26 | 60-min final slot per group: 20-min presentation + 10-min demo + 20-min Q&A |

Target: **baseline fully working by 2026-05-03** so the intermediate report has real profiling numbers.

## 4. Assessment

- **Group grade:** intermediate report, final presentation + demo, submitted artifact archive (RTL, LLVM mods, build/run scripts).
- **Individual adjustment:** ±1 from peer review (Buddy Check) and individual Q&A performance.
- Criteria: solution fit, implementation efficiency, technical depth + analysis, presentation clarity.
- All submissions are originality-checked.

## 5. Platforms

### 5.1 Development server (authoritative)

- **Host:** `ce-procdesign01.ewi.tudelft.nl`
- **User:** `cese4040-24` (shared group account, credentials in `~/.config/pdp-project-24/credentials.txt`)
- **Home path on the server:** `/data2/home/cese4040-24` (not `/home/...`, not `/data/home/...`). Matters any time an absolute path is needed — Vivado error messages, SSHFS mounts, hard-coded TCL paths, etc.
- **Access:** SSH from campus; EduVPN required off-campus. GUI via X2GO (MATE session). VSCode Remote-SSH works for editing.
- **Logout habit:** log out via the GUI — don't just close the client. Stale sessions are killed after 4 hours.
- **Toolchain paths (pre-installed):**
  - RISC-V GCC: `/data/mirror/riscv` (prefix `riscv32-unknown-elf-`)
  - LLVM (clang/lld): `/data/mirror/llvm/build-release`
- **Vivado:** `/opt/apps/xilinx/Vivado/2024.2/bin/vivado` (v2024.2).
- **Course material:** the README mentions a `~/course/` tree, but **it does not exist on `ce-procdesign01`**. The toolchains are just centrally installed at `/data/mirror/riscv` and `/data/mirror/llvm/build-release`, which is already what `software/config/rv32-standard.conf` references. Nothing to copy unless/until we want to rebuild LLVM with a custom pass (then clone the upstream llvm-project into `$HOME`).
- **Sources:** the repo is cloned on the server at `~/pdp-project/` via **HTTPS with a gitlab PAT** (SSH-git doesn't work — see below). The PAT is stored in `~/.git-credentials` (chmod 600) on the server and referenced by a `credential.helper` in `~/.gitconfig`, so `git pull` / `git push` on the server are silent.
  - PAT lives in `~/.config/pdp-project-24/credentials.txt` on the laptop as `PDP_GITLAB_TOKEN` (owner: NetID `datyukov`, scopes `read_repository` + `write_repository`, expiry 2026-06-30).
  - **Shared-account risk:** `~/.git-credentials` is chmod 600 but on a shared group account — teammates logging in as `cese4040-24` can read the token. Because it's a PAT (revocable, scoped to this repo), worst case = someone pushes junk to our gitlab; revoke + regenerate if that happens.
- **SSH gotcha — sshd StrictModes:** the shared group account ships with `$HOME` as `drwxrws---` (group-writable), which makes OpenSSH silently reject every pubkey. `setup-server-auth.sh` fixes this automatically (`chmod g-w ~`). If a teammate hits "Permission denied (publickey)" after adding their key, this is almost certainly why.
- **Network gotcha — outbound port 22 blocked:** the server can reach `gitlab.ewi.tudelft.nl:443` but **not** `:22`, so SSH-git fails with "Connection refused". HTTPS-git with a PAT is the only workable path from the server. Gitlab also enforces **token-only auth** for HTTPS (NetID password is refused with "you're required to use a token instead").

### 5.2 FPGA board

- **Digilent PYNQ-Z1** (Zynq-7000, hardened ARM Cortex-A9 PS + PL fabric).
- Boot: JP4 jumper = SD, JP5 = USB (or REG for 12V barrel).
- Access: direct Ethernet to laptop → static IP → `http://192.168.2.99` (login `xilinx` / `xilinx`). Jupyter runs on the PS; an Overlay loads our bitstream + `.hwh` into the PL.
- **Programming the board** (from the professor): build the bitstream on the server, then **transfer it to this laptop**, then upload to the PYNQ via its browser UI. Transfer options, in order of convenience for us on Linux:
  1. `scp` via `./scripts/fetch-from-server.sh --bitstream` — pulls `riscv_wrapper.bit` + `.tcl` + `riscv.hwh` into `artifacts/` on this laptop.
  2. SSHFS mount (`./scripts/mount-server.sh`) and copy out of `~/pdp-server-mnt/pdp-project/hardware/vivado/...`.
  3. Push from server to gitlab, pull here.
  4. X2GO "shared folders" feature (works but slower).
  5. MobaXterm / WinSCP — Windows only, not our path.

### 5.3 Local (this laptop)

- Local clone of `pdp-project-24/` is for editing + git. Heavy tools (Vivado 2024.2, LLVM, riscv-gnu-toolchain) live on the server.
- SSH key: `~/.ssh/id_ed25519_tudelft` (same key used for gitlab).

## 6. Helper scripts (this workspace)

Run all from `tud-processor-design-project/`:

```bash
# One-time: push our SSH pubkey to the server (uses the password from credentials.txt once)
./scripts/setup-server-auth.sh

# SSH into the server (passwordless after setup-server-auth.sh)
./scripts/connect-server.sh
# ... or one-shot a command:
./scripts/connect-server.sh 'ls -la ~/pdp-project'

# Mount the server's $HOME locally at ~/pdp-server-mnt (SSHFS)
./scripts/mount-server.sh
./scripts/umount-server.sh

# Pull artifacts (bitstream etc.) from the server to ./artifacts/ on this laptop
./scripts/fetch-from-server.sh --bitstream
./scripts/fetch-from-server.sh '~/pdp-project/some/file' ./somewhere/
```

With the SSHFS mount, Claude Code can Read / Edit server files directly at `~/pdp-server-mnt/...` — useful for inspecting generated artifacts, editing config files on the server without leaving this workspace, or tailing logs.

## 7. Canonical build/run flow (on the server)

From `~/pdp-project/hardware/` in Vivado's TCL console:

```tcl
source ./scripts/create_project.tcl            # create baseline RISCY project
source ./scripts/run_simulation.tcl            # ~1–4 min behavioural sim
source ./scripts/create_project_ooc_synth.tcl  # fast OOC synth of just the core
source ./scripts/run_synth_impl.tcl            # full synth + impl (after create_project.tcl)
source ./scripts/gen_bitstream.tcl             # create project + bitstream in one shot
```

Outputs:
- Full bitstream: `hardware/vivado/riscy/riscy.runs/impl_1/riscv_wrapper.bit`
- Hardware handoff for PYNQ: `hardware/vivado/riscy/riscy.gen/sources_1/bd/riscv/hw_handoff/riscv.hwh`
- OOC reports: `hardware/vivado/ooc_riscy/ooc_riscy.runs/ooc_synth/`

Software side (from `~/pdp-project/software/`):

```bash
make soft                                         # output/soft.elf + bin_files/*.coe
cp bin_files/*.coe ../hardware/src/sw/mem_files/  # refresh sim inputs
```

The `.coe` copy step is the most common footgun — without it, simulation runs stale code.

## 8. Baseline reference numbers (untouched system)

**Our measured baseline** (all verified 2026-04-24, shipped sources, Vivado 2024.2, unmodified RTL + C):

| Metric | Value | Source |
|---|---:|---|
| Sim cycles (fetch-enable → end sentinel) | **59,560** | `mem_snoop_match.CLK_COUNT` reported by `zynq_tb.sv` |
| Ciphertext | `fba50914 714bf41f 2e25aabe aaf9080f` (PASSED) | AES-128 test output |
| OOC LUTs | **5,691** | Cell Usage: 7 LUT1 + 369 LUT2 + 1383 LUT3 + 516 LUT4 + 808 LUT5 + 2608 LUT6 |
| OOC Registers | **2,524** | 2154 FDCE + 9 FDPE + 361 FDRE |
| OOC DSPs | **5** | `cv32e40p_mult` + `cv32e40p_ex_stage` multiplier operators (DSP48E1) |
| OOC WNS (setup) | **+5.513 ns** | Timing MET, 0 failing endpoints out of 4342 |
| OOC WHS (hold) | +0.254 ns | MET |
| xsim peak memory | ~8.5 GB | Info for capacity planning on shared server |

**Key derived number: max theoretical clock ≈ 222 MHz** (1 / (10 ns period − 5.513 ns slack)). The OOC constraint appears to be 100 MHz; we have ~5.5 ns to "spend" on combinational depth before violating setup. Task 2.1 (AES SBox + MixColumns in ALU) fits comfortably within this budget.

**C→COE→sim pipeline verified**: `make soft` produces `.coe` byte-identical to shipped `hardware/src/sw/mem_files/*.coe`. Full chain reproducible from source.

**Course-published reference numbers (for context only, don't use as target):**
- Course PDF says 161,441 cycles / ~6,992 LUTs / ~2,486 regs / 23 DSPs / WNS ~+2.131 ns. Ours differ because (likely) course ran different Vivado version, and the 23-DSP figure probably includes the AXI smartconnect infra that our OOC flow excludes. **Always report our numbers against our own 59,560-cycle / 5,691-LUT / +5.513 ns baseline**, not the course PDF.

**Benign warnings / known-good noise** (ignore these in output):
- `WARNING: 0ns: none of the conditions were true for unique case` — time-0 X-propagation artifact.
- `ERROR: XILINX_RESET_PULSE_WIDTH` from AXI VIP — reset best-practice check; sim correct regardless.
- `WARNING: [Timing 38-242] HD.CLK_SRC ... not set` in OOC mode — just disables clock-buffer delay estimation; timing numbers still valid.
- `WARNING: No cells matched 'RISCV_CORE'` at end of OOC synth — stale course TCL trying to report a non-existent cell. Synth itself succeeded; ignore.
- **End sentinel:** `mem_snoop_match` watches for `0xDEADBEEF` at `0x2000`; it also counts cycles since fetch-enable. Do not remove the end sentinel from `main.c` — the testbench uses it to stop sim.

**Benign warnings we can ignore** (Vivado's known quirks, not signs of a broken baseline):
- `WARNING: 0ns: none of the conditions were true for unique case` — fires once at time-0 when all signals are X; doesn't affect correctness.
- `ERROR: XILINX_RESET_PULSE_WIDTH` from the AXI VIP — reset best-practice check; the design still simulates correctly.

Future improvements get measured against our 59 560-cycle baseline.

## 9. Two-phase workflow

### Phase 1 — bring-up + plan (weeks 1–2, ending 2026-05-08)

- [ ] Task 1.1 — Synthesize RISCY + peripherals, load onto PYNQ-Z1, cross-compile + run baseline AES.
- [ ] Task 1.2 — Profile bottlenecks (any mix of analytical modelling, static analysis, dynamic profiling on the simulator or FPGA). Methodology and its limits must be stated.
- [ ] Intermediate report (Brightspace quiz):
  - Proposed target metric(s) + justification.
  - State-of-the-art we compare against (background section).
  - Planned experimental methodology → quantitative evidence.
  - Internal task breakdown with owners, dependencies, milestones.

### Phase 2 — implement + evaluate (weeks 3–8, ending 2026-06-12)

- [ ] Task 2.1 — Implement `aes32esi` + `aes32esmi` in RISCY, expose through LLVM, then apply the built-in loop-unroll pass and measure.
- [ ] Task 2.2 — Implement the group-specific improvements from the Phase 1 plan; measure against the agreed baseline; iterate.
- [ ] Task 2.3 — Prepare presentation, live demo, and the submission archive (modified RTL, LLVM mods, build/run scripts, anything else written/changed).

## 10. Per-change iteration loop

1. Change C / LLVM → `make soft` → copy `.coe`s → re-run `run_simulation.tcl`.
2. Change RTL → re-run `run_simulation.tcl`; if it passes, run OOC synth to check timing + area.
3. When both pass → regenerate bitstream → test on PYNQ-Z1 via Jupyter (`base_riscy.ipynb`).
4. Record numbers. Decide next step.

## 11. Support model

- **Brightspace:** primary channel, authoritative for schedule + assignments.
- **Teams:** per-group private channel (named after group number = **24**) with TAs + course team.
- **Labs:** Fridays 13:45–17:45, EWI-Tellegen Hall practicumzalen 1/2/3.
- TAs help with conceptual + infrastructure issues. They will **not** debug local installs or our RTL/compiler code for us.

## 12. External references

- RISC-V Scalar Crypto Extensions, v0.9.3 (14 June 2021) — canonical `aes32esi` / `aes32esmi` encoding.
- OpenHW Group CV32E40P User Manual — authoritative RISCY reference (supersedes older PULP docs).
- Course website: https://cese.ewi.tudelft.nl/processor-design-project/index.html (not kept up to date — reference only).
- PYNQ-Z1 setup: https://pynq.readthedocs.io/en/latest/getting_started/pynq_z1_setup.html
- X2GO for QCE servers: https://qce-it-infra.ewi.tudelft.nl/faq.html#how-to-setup-x2go-for-the-qce-xportal-server
