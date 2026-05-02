# Profiling instrumentation snapshots

These four files are snapshots of the dynamic-profiling instrumentation
work for **Task #6** (see `../PROFILING.md` § 7). They are *not* the
canonical source — those live in the GitLab repo (`pdp-project-24/`) and
on the server at `~/pdp-project/`. These copies exist purely so the
GitHub repo carries a self-contained record of what was modified to
generate the dynamic-profiling numbers in the intermediate report.

## Files

| File | Purpose |
|---|---|
| `main.baseline.c` | Original `software/main.c` from the GitLab repo (pre-instrumentation, for diff/revert reference) |
| `main.instrumented.c` | Modified `software/main.c` with `mcycle` CSR reads bracketing each AES phase + `csrwi 0x320, 0` to enable counters |
| `zynq_tb.baseline.sv` | Original `hardware/src/simulation/zynq_tb.sv` from the GitLab repo |
| `zynq_tb.instrumented.sv` | Modified testbench with 6 extra `read_data` + `$display` calls to print the per-function cycle profile |

## How they were used

1. Both instrumented files were placed at their canonical paths on the
   server (`~/pdp-project/software/main.c` and
   `~/pdp-project/hardware/src/simulation/zynq_tb.sv`).
2. `make soft` rebuilt the AES binary against the new `main.c`.
3. `cp bin_files/*.coe ../hardware/src/sw/mem_files/` refreshed the
   BRAM init data.
4. Vivado re-ran the simulation (`source ./scripts/run_simulation.tcl`).
5. The testbench printed per-function cycle deltas to the Tcl console.
6. Numbers were captured into `../PROFILING.md` § 7.

## Why these aren't committed to the GitLab course repo

The instrumentation is *throwaway profiling scaffolding* — it has no
place in the course-graded RTL/C submission. Keeping it as a separate
snapshot in this personal GitHub repo means:

- The instrumentation is preserved for future reference / re-running.
- The GitLab `main` branch stays clean for course submission.
- Reverting the server is one `cp ...baseline.bak ...c` away (see
  backups on the server itself at `~/pdp-project/software/main.c.baseline.bak`
  and `~/pdp-project/hardware/src/simulation/zynq_tb.sv.baseline.bak`).

## Reproducing the dynamic profiling

If a teammate (or future-you) wants to re-run dynamic profiling from
scratch on the server:

```bash
cp profiling-instrumentation/main.instrumented.c ~/pdp-project/software/main.c
cp profiling-instrumentation/zynq_tb.instrumented.sv ~/pdp-project/hardware/src/simulation/zynq_tb.sv
cd ~/pdp-project/software
make soft
cp bin_files/*.coe ../hardware/src/sw/mem_files/
# then in Vivado Tcl console:
#   close_sim -quiet
#   source ./scripts/run_simulation.tcl
```

To revert:

```bash
cp profiling-instrumentation/main.baseline.c ~/pdp-project/software/main.c
cp profiling-instrumentation/zynq_tb.baseline.sv ~/pdp-project/hardware/src/simulation/zynq_tb.sv
```
