# PDP Group 24 — Progress Tracker

Living document. Whoever opens this next — start here.

**Today (2026-04-24):** Phase 1 bring-up completed end-to-end. Baseline
measured, pipeline verified, profiling analysis written. Next working
session should open this file first for context.

---

## Quick status

| Phase | Status |
|---|---|
| **Phase 1: bring-up + plan** | ✅ Tooling + baseline done. ⏳ FPGA + report remain. |
| **Phase 2: implement + evaluate** | ⏳ Not started (begins after 2026-05-08 report). |

## Deadlines (in order)

| Date | Milestone |
|---|---|
| Fri 2026-05-01 13:45–17:45 | **Lab session** — FPGA bring-up on PYNQ-Z1 with TA support |
| Mon 2026-05-04 | Brightspace intermediate-report quiz **opens** |
| **Fri 2026-05-08 23:59** | **Intermediate report due** (Brightspace, one submission per group) |
| Fri 2026-06-12 | End of week 8: source archive + presentation slides |
| Weeks 25–26 | 60-min final slot per group (20 pres + 10 demo + 20 Q&A) |

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
- [x] **Static profiling:** `mix_columns` is 55% of cycles, ~37k total instrs, CPI ≈ 1.61 (see `PROFILING.md`)

### Documentation artifacts

- [x] `CLAUDE.md` — project context (auto-loaded by Claude Code)
- [x] `BASELINE.md` — measured baseline (cycles, area, timing)
- [x] `PROFILING.md` — static analysis, projected Phase 2 speedup
- [x] `PROGRESS.md` — this file
- [x] Memory files under `~/.claude/projects/.../memory/` keep state across sessions

---

## What's left — ordered by urgency

### Before Fri 2026-05-01 lab (1 week)

- [ ] **Sanity-check PYNQ-Z1 connectivity at home** (5 min). Plug board into laptop via Ethernet, confirm you can reach `http://192.168.2.99` and log in as `xilinx / xilinx`. If it fails, bring the failure to Friday's lab for TA help — don't spend hours debugging solo.
- [ ] **Task 7: Generate full bitstream** (~20–30 min, server). Run in Vivado Tcl console:
  ```tcl
  source ./scripts/gen_bitstream.tcl
  ```
  Then pull the artifact home:
  ```bash
  ./scripts/fetch-from-server.sh --bitstream
  ```
  Produces `artifacts/riscv_wrapper.bit` + `riscv_wrapper.tcl` + `riscv.hwh` on the laptop. Needed for the lab.

### During Fri 2026-05-01 lab

- [ ] **Task 8: PYNQ-Z1 FPGA bring-up.** Upload bitstream via browser/Jupyter, run `base_riscy.ipynb`, confirm AES output matches sim (`fba50914 714bf41f 2e25aabe aaf9080f`). TA support available.

### Before Fri 2026-05-08 23:59 (intermediate report)

- [ ] **Task 6: Dynamic profiling** (~1–2 hours, optional but strengthens the report). Instrument `main.c` with `rdcycle` CSR reads around each AES function, rebuild, re-run sim, report per-function cycle costs. Compare against the static estimates in `PROFILING.md`.
- [ ] **Task 9: Draft intermediate report** (Brightspace quiz, opens 2026-05-04). Contents per rubric:
  - (a) Proposed target metric + justification → **cycle reduction on AES-128 encryption**
  - (b) State-of-the-art background → RISC-V Zkne v0.9.3 spec, CV32E40P docs, scalar-crypto papers
  - (c) Planned methodology → cite `BASELINE.md` numbers, cite `PROFILING.md` 55% breakdown
  - (d) Internal task breakdown — who does what among the 4 teammates, with milestones
- [ ] **Coordinate with teammates** in Teams Group 24 channel — split up Phase 2 work: (i) RTL (someone writes `aes32esmi`/`aes32esi` in `cv32e40p_alu.sv` + decoder), (ii) LLVM pass, (iii) test/sim/bitstream harness, (iv) report writing.

### Phase 2 — starts 2026-05-09 after the report

- [ ] **Task 2.1a: Implement `aes32esmi` + `aes32esi` in RISCY RTL**. Files to touch: `hardware/src/design/riscy/cv32e40p_decoder.sv`, `cv32e40p_alu.sv`, possibly `cv32e40p_pkg.sv`. Reference: RISC-V Scalar Crypto v0.9.3 spec, section for Zkne encodings.
- [ ] **Task 2.1b: Expose through LLVM**. First approach = inline asm in `main.c`. Proper approach = LLVM intrinsic in the RISC-V backend; requires rebuilding LLVM (the `/data/mirror/llvm/build-release` tree is a release build, we'd need to clone llvm-project and add our own scalar-crypto extension in our `$HOME`).
- [ ] **Task 2.1c: LLVM loop-unroll pass on middle-round MixColumns loop** — course-mandated as a built-in pass. Apply via `-mllvm -unroll-count=4` on the hot loop, or write a simple pass that targets the mix_columns outer loop.
- [ ] **Task 2.2: Group-specific improvement** (TBD by group). Options from course brief: latency, throughput, area, memory footprint, register pressure, side-channel resistance, custom LLVM passes. Pick in the intermediate report, implement in Phase 2.
- [ ] **Task 2.3: Final deliverables** (due 2026-06-12). RTL + LLVM mods + build/run scripts archive, final-presentation slides, live demo script.

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

- **Server is shared-group account** (`cese4040-24`, 4 teammates). Don't kill X2Go sessions you don't recognize — they're your teammates' work.
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
