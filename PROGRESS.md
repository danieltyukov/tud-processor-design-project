# PDP Group 24 — Progress Tracker

Living document. Whoever opens this next — start here.

**Today (2026-05-08, intermediate report due 23:59):** Phase 1
bring-up done; baseline measured + post-impl baseline (Rishi)
captured; bitstream generated and pulled to `artifacts/`. Team has
firmed up Q1 #3 as **the AES "super-instruction"** (Pan et al. 2021
inspiration), with side-channel resistance (Kassimi/Taouil 2026)
deferred as a stretch goal. Hruday's draft folded into
`REPORT_INTERMEDIATE.md` Q1–Q5 with team ownership tables. Next
working session should open this file first for context.

### Recent updates

**2026-05-06 (Rishi):** post-implementation reports (utilization /
timing / power) on the unmodified design — full design closes at
20 MHz with +28.306 ns WNS, 10,171 LUTs / 8,522 FFs / 16 BRAMs /
5 DSPs, 1.419 W on-chip (95 % is the always-on PS7). Snapshot at
[`baselines/post-impl-2026-05-06/`](./baselines/post-impl-2026-05-06/README.md).

**2026-05-06 (Vishnu + Hruday):** state-of-the-art research papers
shared via chat — both copied into [`references/`](./references/README.md)
with notes:
- **Kassimi A. et al. (TU Delft, 2026)** — "Secure Implementation of
  RISC-V's Scalar Cryptography Extension Set". DOM-protected Zkne
  on CV32E40S, +0.39 % area / 0 % perf overhead. Validation requires
  ChipWhisperer (we don't have one) → harder to validate end-to-end.
- **Pan L. et al. (Wuhan, 2021)** — "A Lightweight AES Coprocessor
  Based on RISC-V Custom Instructions". 25–38 % runtime gain on
  Hummingbird E203. Their full design > our 8-week budget; we adapt
  the kernel idea (fuse 4 chained `aes32esmi` into 1 super-instruction).

**2026-05-07 (Vishnu's plan + team Teams discussion):** all three
improvements agreed for the report — Zkne instructions (mandatory)
+ LLVM loop unroll (mandatory) + super-instruction (group-specific).
Side-channel deferred. Hruday drafted Brightspace answers in
[`drafts/2026-05-08-hruday-quiz-draft.txt`](./drafts/2026-05-08-hruday-quiz-draft.txt);
folded into `REPORT_INTERMEDIATE.md`.

**2026-05-08 (Daniel):** generated the project's first
self-built bitstream via headless `vivado -mode batch -source
./scripts/gen_bitstream.tcl` on the server (~18 min); pulled to
[`artifacts/`](./artifacts/) on the laptop. Identical 4,045,673-byte
size to the course-shipped `base_riscy.bit` (same source, same
toolchain). Also fixed `scripts/fetch-from-server.sh --bitstream`
which had a `$HOME`-vs-scp bug.

### Team

Group 24 has **5 members**. Roles for the report (Phase 2 split is the same — see `REPORT_INTERMEDIATE.md` Q4):

- **Daniel Tyukov** (datyukov) — repo + GitHub mirror + helper scripts; report compilation; baseline measurement.
- **Rishi** — Vivado implementation flow; area/power/timing post-impl reports; baseline co-owner.
- **Vishnu Karthik** — state-of-the-art research; supervisor liaison (emailing Prof. Mottah Taouil); side-channel track if we revive it.
- **Hruday Gowda** — instruction-set research; super-instruction track lead; quiz writer.
- **Sathya** — validation / measurement track lead. *(Confirm surname + NetID before final submission.)*

---

## Quick status

| Phase | Status |
|---|---|
| **Phase 1: bring-up + plan** | ✅ Tooling, baselines, profiling, bitstream done. ⏳ Report submission tonight; FPGA-board verification still pending. |
| **Phase 2: implement + evaluate** | ⏳ Starts 2026-05-09. Task table in `REPORT_INTERMEDIATE.md` Q4 (A1–A6 / B1–B5 / C1–C7) is the working plan. |

## Deadlines (in order)

| Date | Milestone | Status |
|---|---|---|
| Fri 2026-05-01 13:45–17:45 | Lab session — FPGA bring-up support | ✅ passed |
| Mon 2026-05-04 | Brightspace intermediate-report quiz opens | ✅ |
| **Fri 2026-05-08 23:59** | **Intermediate report due** (one submission per group) | ⏳ **TODAY** |
| Sat 2026-05-23 | M2: `aes32esi`/`aes32esmi` RTL + sim PASSED | ⏳ Phase 2 |
| Tue 2026-06-02 | M3: LLVM intrinsics + loop unroll | ⏳ Phase 2 |
| Tue 2026-06-09 | M4: super-instruction + PYNQ verification | ⏳ Phase 2 |
| Fri 2026-06-12 | M5: source archive + presentation slides | ⏳ Phase 2 |
| Weeks 25–26 | 60-min final slot per group (20 pres + 10 demo + 20 Q&A) | ⏳ |

---

## Done ✅

### Workspace + server

- [x] Laptop ↔ server SSH with pubkey (agent-forwarded, sshpass fallback): `scripts/setup-server-auth.sh`, `connect-server.sh`
- [x] SSHFS mount of server `$HOME` at `~/pdp-server-mnt`: `scripts/mount-server.sh`
- [x] Gitlab repo cloned on server via **HTTPS + PAT** (port 22 outbound blocked): `~/pdp-project/` on server
- [x] Token stored in `~/.git-credentials` (chmod 600) on the server, referenced via `~/.gitconfig`
- [x] Credentials single source of truth: `~/.config/pdp-project-24/credentials.txt` on laptop (chmod 600)

### GUI access

- [x] X11 forwarding path: `scripts/launch-vivado.sh` (good for quick one-offs)
- [x] X2Go MATE desktop path: `scripts/launch-x2go.sh` (recommended for long Vivado sessions)
- [x] DPI scaling fixed (seeded session has `setdpi=true`, `dpi=96`, 1920×1200)

### Baseline verification

- [x] **Simulation baseline:** 59,560 cycles, ciphertext correct, test PASSED (see `BASELINE.md`)
- [x] **C → COE pipeline proven reproducible:** `make soft` produces byte-identical `.coe` (diff empty). Shipped `.coe` backed up at `hardware/src/sw/mem_files.shipped.bak/` on server
- [x] **OOC synthesis measured:** 5,691 LUTs / 2,524 regs / 5 DSPs / WNS +5.513 ns (see `BASELINE.md`)
- [x] **Post-implementation snapshot (2026-05-06, Rishi):** 10,171 LUTs / 8,522 regs / 16 BRAMs / 5 DSPs / WNS +28.306 ns @ 20 MHz; total power 1.419 W (PS7 dominates). See `baselines/post-impl-2026-05-06/README.md`.
- [x] **Static profiling:** `mix_columns` is 55% of cycles (estimate), ~37k total instrs, CPI ≈ 1.61 (see `PROFILING.md` § 1-6)
- [x] **Dynamic profiling (2026-05-02):** `mix_columns` measured at **83.8%** of cycles (50,643 of 60,457). Cross-validates static. Key finding: dominance is even larger than estimated → Phase 2 deliverables can plausibly hit 3-5× speedup (see `PROFILING.md` § 7-8)

### FPGA bring-up

- [x] **Bitstream generated 2026-05-08:** headless `vivado -mode batch -source ./scripts/gen_bitstream.tcl` on the server (~18 min wall-clock), then `./scripts/fetch-from-server.sh --bitstream`. Files in `artifacts/`: `riscv_wrapper.bit` (4,045,673 B), `riscv.hwh` (293,325 B), `riscv_wrapper.tcl` (12,355 B).
- [x] **`fetch-from-server.sh --bitstream` bug fixed** — was passing literal string `$HOME` to scp (no remote shell expansion); switched to scp tilde-expansion via `~`-relative paths.

### Documentation artifacts

- [x] `CLAUDE.md` — project context (auto-loaded by Claude Code)
- [x] `BASELINE.md` — measured baseline (cycles, OOC area, OOC timing)
- [x] `baselines/post-impl-2026-05-06/README.md` — Rishi's post-impl baseline (full design, routed)
- [x] `PROFILING.md` — static analysis, projected Phase 2 speedup
- [x] `PROGRESS.md` — this file
- [x] `REPORT_INTERMEDIATE.md` — Brightspace Q1–Q5 prose draft (folded in Hruday's draft + papers + baselines)
- [x] `references/README.md` — Kassimi/Taouil 2026 + Pan 2021 papers with notes
- [x] `drafts/2026-05-08-hruday-quiz-draft.txt` — team's working text
- [x] Memory files under `~/.claude/projects/.../memory/` keep state across sessions

---

## What's left — ordered by urgency

### Tonight before 2026-05-08 23:59 (intermediate report)

- [ ] **Final read-through of `REPORT_INTERMEDIATE.md` Q1–Q5** with the team. Specifically:
  - Confirm side-channel option is **deferred** (current draft) vs. **pitched as parallel track**.
  - Confirm Sathya's surname + NetID for the team list.
  - Spot-check Q4 ownership against what teammates expect to do.
- [ ] **Submit Brightspace quiz** (one person, copy each Q1–Q5 section in). Probably Daniel.
- [ ] **Push everything to GitHub** so the team has visibility (papers, drafts, baselines/, REPORT_INTERMEDIATE.md, fixed fetch script).

### After the report — quick wins (2026-05-09 weekend)

- [ ] **PYNQ-Z1 FPGA bring-up.** Plug board into laptop via Ethernet → `http://192.168.2.99` (xilinx/xilinx) → upload `artifacts/riscv_wrapper.bit` + `riscv.hwh` + `riscv_wrapper.tcl` via Jupyter → run `base_riscy.ipynb` → confirm ciphertext = `fba50914 714bf41f 2e25aabe aaf9080f`. (Bitstream is ready, just need to load it.)
- [ ] **Sanity-check `aes32esi`/`aes32esmi` opcode space** in `cv32e40p_decoder.sv` — make sure the encoding we want isn't shadowed by Xpulp custom ops.

### Phase 2 (2026-05-09 → 2026-06-12)

The detailed task table lives in `REPORT_INTERMEDIATE.md` Q4 — A1–A6 (Integration), B1–B5 (Baseline, mostly done), C1–C7 (Validation). Don't duplicate it here. Cross-track milestones:

- **M2 — 2026-05-23:** `aes32esi` + `aes32esmi` decoded + executed in RTL; sim PASSED.
- **M3 — 2026-06-02:** LLVM toolchain emits both new instructions; loop-unroll pass active.
- **M4 — 2026-06-09:** Super-instruction (custom-0 fused middle-round op) implemented + measured + verified on PYNQ-Z1.
- **M5 — 2026-06-12:** Final source archive + slides + demo script submitted.

---

## How to pick up next session

**New Claude Code session in this directory auto-loads:**

1. `CLAUDE.md` at workspace root — project overview
2. Memory files at `~/.claude/projects/-home-danieltyukov-workspace-tud-tud-processor-design-project/memory/*.md` — user context, baseline numbers, server setup

**First thing to do in the next session:**

1. Open `PROGRESS.md` (this file) — confirm what's done/next
2. Open `BASELINE.md` — remind self of the numbers
3. Open `PROFILING.md` — remind self of the analysis
4. Check the TODO list to pick the next concrete task

**If the server state has drifted** (e.g. teammate used the account, sessions expired):

```bash
# Re-establish SSH + verify
./scripts/connect-server.sh 'pwd && ls ~/pdp-project | head'

# Re-mount SSHFS if needed
./scripts/mount-server.sh

# Before running anything heavy, clean up any orphan Vivado processes:
./scripts/connect-server.sh 'pkill -KILL -u $USER -f "vivado|xsim|xelab|xvlog" 2>/dev/null; ps -u $USER -o pid,cmd | grep -i viv | grep -v grep'
```

**If the Vivado project got wedged** (file locks, NFS silly-renames):

```bash
./scripts/connect-server.sh 'cd ~/pdp-project/hardware/vivado && mv riscy riscy.orphaned.$(date +%s)'
```

Then in Vivado Tcl console:

```tcl
source ./scripts/create_project.tcl
```

---

## Gotchas learned (don't re-learn them)

- **Server is shared-group account** (`cese4040-24`, 5 teammates). Don't kill X2Go sessions you don't recognize — they're your teammates' work.
- **Port 22 outbound blocked on server**: SSH-git to gitlab fails. Only HTTPS+PAT works. PAT is revocable and scoped.
- **Vivado's `create_project.tcl` is destructive** — it deletes `vivado/riscy/` every run. Don't put precious state there.
- **NFS silly-rename** (`.nfsXXXXXX` files) happens when a process got OOM-killed while holding files. Fix: `mv riscy riscy.orphaned.<timestamp>` rather than fighting `rm`.
- **Server home path is `/data2/home/cese4040-24`**, often shown as `/data/home/...` via a symlink. Both resolve. Don't be confused by the two variants in logs.
- **Long commands get wrapped by the X2Go terminal**. Use short relative paths via `cd` first, or environment variables like `A=...` `B=...`, one command per line.
- **xsim peak memory ~8.5 GB** for the full sim. Check `free -h` before launching if server looks busy — other users' jobs can OOM-kill ours.
- **Benign-but-loud warnings** to ignore:
  - `unique case ... none of conditions were true at 0ns` — SV time-0 X propagation
  - `ERROR: XILINX_RESET_PULSE_WIDTH` from AXI VIP — best-practice check, sim correct
  - `HD.CLK_SRC not set` in OOC mode — expected
  - `No cells matched 'RISCV_CORE'` at end of OOC synth — stale TCL query, synth itself succeeded
