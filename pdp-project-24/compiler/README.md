# Compiler: custom LLVM loop-unroll pass

`software/main.c` keeps the AES round loop as a plain loop; full unrolling is
applied at build time by the custom LLVM pass in `aes-unroll-pass/`
(`-fpass-plugin=libAESUnroll.so`), not in the C source. Measured effect on the
hardware-accelerated AES: looped 6,260 cycles to unrolled 4,800 cycles.

## Contents
- `aes-unroll-pass/AESUnroll.cpp`: a Loop pass (`PassInfoMixin`) that identifies
  the AES round loop and fully unrolls it through LLVM's `UnrollLoop()` utility,
  registered as a plugin via `llvmGetPassPluginInfo()`.
- `aes-unroll-pass/CMakeLists.txt`: builds it as a loadable module `libAESUnroll.so`.

## Build and use
```
cd aes-unroll-pass
cmake -B build -DLLVM_DIR=<llvm>/lib/cmake/llvm && cmake --build build
clang -fpass-plugin=build/libAESUnroll.so ...
```
