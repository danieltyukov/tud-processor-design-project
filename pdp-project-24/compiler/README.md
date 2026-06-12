# Compiler — custom LLVM loop-unroll pass

`software/main.c` keeps the AES round loop as a plain loop on purpose; full
unrolling is applied by the **custom LLVM pass in `aes-unroll-pass/`** at build
time (`-fpass-plugin=libAESUnroll.so`), not in the C source (see `main.c`
line ~184). Measured before/after: looped 6,260 -> unrolled 4,800 cycles
(see `../SESSION_NOTES.md`).

## Contents
- `aes-unroll-pass/AESUnroll.cpp` — the pass. A `Loop`-pass (`PassInfoMixin`)
  that identifies the AES round loop and fully unrolls it via LLVM's
  `UnrollLoop()` utility; registered as a plugin through `llvmGetPassPluginInfo()`.
- `aes-unroll-pass/CMakeLists.txt` — builds it as a loadable module `libAESUnroll.so`.

## Build & use
```sh
cd aes-unroll-pass
cmake -B build -DLLVM_DIR=<llvm>/lib/cmake/llvm && cmake --build build
# then compile with:  clang -fpass-plugin=build/libAESUnroll.so ...
```
