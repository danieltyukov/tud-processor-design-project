#!/usr/bin/env python3
"""Run the baseline AES test on the PYNQ-Z2, print cycle count + ciphertext."""
from pynq import Overlay, MMIO
import time, sys

BIT  = "/home/xilinx/jupyter_notebooks/riscy/overlays/base_riscy.bit"
CODE = "/home/xilinx/jupyter_notebooks/riscy/mem_files/code.coe"
DATA = "/home/xilinx/jupyter_notebooks/riscy/mem_files/data.coe"

def parse_coe(path):
    out = []
    parsing = False
    for line in open(path):
        line = line.strip()
        if parsing:
            out.extend([v.strip() for v in line.split(",") if v.strip()])
        if "memory_initialization_vector=" in line:
            parsing = True
            for v in line.split("=", 1)[1].split(","):
                if v.strip(): out.append(v.strip())
    return out

def load_coe(path, write_fn):
    offs = 0
    for v in parse_coe(path):
        write_fn(offs, int(v.rstrip(";"), 16))
        offs += 4
    return offs

print(">>> overlay")
zynq = Overlay(BIT, download=False)
ins_mem       = MMIO(0x40000000, 0x8000)
data_mem      = MMIO(0x42000000, 0x8000)
riscv_control = MMIO(0x40008000, 0x1000)
reg_bank      = MMIO(0x40009000, 0x1000)

print(">>> downloading bitstream")
zynq.download()

print(">>> reset core")
riscv_control.write(0x10, 0x1)
riscv_control.write(0x10, 0x0)

print(">>> load code.coe")
n = load_coe(CODE, ins_mem.write_reg)
print(f"    {n} bytes")
print(">>> load data.coe")
n = load_coe(DATA, data_mem.write_reg)
print(f"    {n} bytes")

print(">>> START (fetch_enable)")
riscv_control.write(0x10, 0x10)

t0 = time.time()
for i in range(200):  # up to ~2s
    if reg_bank.read(0x0) == 1:
        break
    time.sleep(0.01)
elapsed = time.time() - t0

if reg_bank.read(0x0) != 1:
    print(f"!!! test did NOT finish in {elapsed:.2f}s")
    sys.exit(1)

cycles = reg_bank.read(0x4)
result_check = data_mem.read(0x2004)
exp = [data_mem.read(0x2030 + i*4) for i in range(4)]
calc = [data_mem.read(0x2040 + i*4) for i in range(4)]

print()
print("="*60)
print(f"AES RAN ON SILICON ✓     ({elapsed*1000:.1f} ms wall-clock)")
print("="*60)
print(f"  cycle count    = {cycles}    (sim baseline = 59560)")
print(f"  expected       = {''.join(f'{w:08x}' for w in exp)}")
print(f"  calculated     = {''.join(f'{w:08x}' for w in calc)}")
print(f"  result_check   = {hex(result_check)}  "
      f"{'PASSED ✓' if result_check == 0xCAFEBABE else 'FAILED ✗'}")
print("="*60)
