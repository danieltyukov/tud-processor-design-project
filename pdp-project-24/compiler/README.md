# Compiler — custom LLVM loop-unroll pass

`software/main.c` keeps the AES round loop as a plain loop on purpose; full
unrolling is applied by a **custom LLVM pass** (`aes-unroll-pass`) at build time,
not in the C source (see `main.c` line ~184 and `../SESSION_NOTES.md` for the
measured before/after: looped 6,260 -> unrolled 4,800 cycles).

> **TODO (owner: Hruday):** commit the pass source here. It was built into a local
> custom LLVM (clang 23) and is not yet in the repository. Without it, `make soft`
> falls back to the plain loop. Measurements and methodology are in
> `../SESSION_NOTES.md`.
