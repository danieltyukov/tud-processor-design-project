#!/usr/bin/env python3
"""
Run Hruday's hw_aes32esi/esmi self-test on the PYNQ-Z2 using OUR tower-field
zkne bitstream. The self-test program calls hw_aes32esi/esmi for bs=0..3 and
compares results against a software AES reference; writes results + pass/fail
into data BRAM where this runner reads them.

Data-BRAM addresses set by profiling-instrumentation/main.c:
   0x2004 : standard AES ciphertext check  (0xCAFEBABE = match)
   0x2008 : Zkne hw vs sw pass/fail        (0xCAFEBABE = all 8 ops match)
   0x2010..0x201C : aes32esi  hw results, bs=0..3
   0x2020..0x202C : aes32esmi hw results, bs=0..3
   0x2030..0x203C : expected AES ciphertext
   0x2040..0x204C : calculated AES ciphertext
"""
from pynq import Overlay, MMIO
import sys, time, argparse

BIT_DEFAULT  = "/tmp/zkne_tower.bit"
CODE_DEFAULT = "/tmp/code.coe"
DATA_DEFAULT = "/tmp/data.coe"


def parse_coe(path):
    out, parsing = [], False
    for line in open(path):
        line = line.strip()
        if parsing:
            out.extend([v.strip() for v in line.split(",") if v.strip()])
        if "memory_initialization_vector=" in line:
            parsing = True
            for v in line.split("=", 1)[1].split(","):
                if v.strip():
                    out.append(v.strip())
    return out


def load_coe(path, write_fn):
    offs = 0
    for v in parse_coe(path):
        write_fn(offs, int(v.rstrip(";"), 16))
        offs += 4
    return offs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bit",  default=BIT_DEFAULT)
    ap.add_argument("--code", default=CODE_DEFAULT)
    ap.add_argument("--data", default=DATA_DEFAULT)
    args = ap.parse_args()

    print(f">>> overlay {args.bit}")
    zynq = Overlay(args.bit, download=False)
    ins_mem       = MMIO(0x40000000, 0x8000)
    data_mem      = MMIO(0x42000000, 0x8000)
    riscv_control = MMIO(0x40008000, 0x1000)
    reg_bank      = MMIO(0x40009000, 0x1000)

    print(">>> downloading bitstream")
    zynq.download()
    print(">>> reset core")
    riscv_control.write(0x10, 0x1); riscv_control.write(0x10, 0x0)
    print(f">>> load code  ({args.code})")
    print(f"    {load_coe(args.code, ins_mem.write_reg)} bytes")
    print(f">>> load data  ({args.data})")
    print(f"    {load_coe(args.data, data_mem.write_reg)} bytes")
    print(">>> START")
    riscv_control.write(0x10, 0x10)

    t0 = time.time()
    for _ in range(300):
        if reg_bank.read(0x0) == 1: break
        time.sleep(0.01)
    elapsed = time.time() - t0
    if reg_bank.read(0x0) != 1:
        print(f"!!! did not finish in {elapsed:.2f}s"); sys.exit(1)

    cycles      = reg_bank.read(0x4)
    aes_check   = data_mem.read(0x2004)
    zkne_check  = data_mem.read(0x2008)
    esi_results  = [data_mem.read(0x2010 + i*4) for i in range(4)]
    esmi_results = [data_mem.read(0x2020 + i*4) for i in range(4)]
    expected     = [data_mem.read(0x2030 + i*4) for i in range(4)]
    calculated   = [data_mem.read(0x2040 + i*4) for i in range(4)]

    print()
    print("=" * 60)
    print(f"BITSTREAM RAN ON SILICON  ({elapsed*1000:.1f} ms wall-clock)")
    print("=" * 60)
    print(f"  cycle count        = {cycles}")
    print()
    print(f"  AES ciphertext check  = {hex(aes_check):>14}   "
          f"{'PASSED' if aes_check == 0xCAFEBABE else 'FAILED'}")
    print(f"  Zkne hw == sw check   = {hex(zkne_check):>14}   "
          f"{'PASSED' if zkne_check == 0xCAFEBABE else 'FAILED'}")
    print()
    print("  aes32esi  hw results (rs1=0x12345678, rs2=0xAABBCCDD):")
    for bs, v in enumerate(esi_results):
        print(f"     bs={bs}  hw=0x{v:08x}")
    print("  aes32esmi hw results:")
    for bs, v in enumerate(esmi_results):
        print(f"     bs={bs}  hw=0x{v:08x}")
    print()
    print(f"  expected ciphertext = {''.join(f'{w:08x}' for w in expected)}")
    print(f"  calculated          = {''.join(f'{w:08x}' for w in calculated)}")
    print("=" * 60)

    sys.exit(0 if (aes_check == 0xCAFEBABE and zkne_check == 0xCAFEBABE) else 2)


if __name__ == "__main__":
    main()
