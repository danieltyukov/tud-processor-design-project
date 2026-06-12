# =============================================================================
# Toolchain
# Custom local LLVM for aes32 super opcodes.
# GCC sysroot from server used only for headers (--sysroot), not for libs.
# =============================================================================
LLVM_ROOT := /home/kaarviii/Desktop/llvm-project/build-release/bin
LLVMCC    := $(LLVM_ROOT)/clang
OBJCOPY   := $(LLVM_ROOT)/llvm-objcopy
LD        := $(LLVM_ROOT)/ld.lld

# GCC sysroot — headers only (libc.a not available locally or on server)
SYSROOT   := /data/mirror/riscv/riscv32-unknown-elf

# =============================================================================
# Architecture
# conf file used export-syntax which Make cannot parse, so values are set here
# directly. -march is overridden to rv32imc_zkne for the custom opcodes.
# rv32imac_zicsr from the conf is intentionally replaced — 'a' (atomics) and
# zicsr are not needed for the AES target and zkne supersedes them here.
# =============================================================================
ARCH    := rv32imc_zkne
ABI     := ilp32
OPT     := -Os

# =============================================================================
# Directories
# =============================================================================
SOFT_DIR    := soft
ACC_DIR     := acc
INCLUDE_DIR := include
OUTPUT_DIR  := output
BIN_DIR     := bin_files

$(shell mkdir -p $(OUTPUT_DIR) $(BIN_DIR))

# =============================================================================
# Compiler flags (compile-only — no link-time flags here)
# =============================================================================
CFLAGS  = --target=riscv32
CFLAGS += -march=$(ARCH)
CFLAGS += -mabi=$(ABI)
CFLAGS += $(OPT)
CFLAGS += -Wall
CFLAGS += -I./share
CFLAGS += -I./$(SOFT_DIR)
CFLAGS += -I./$(ACC_DIR)
CFLAGS += -I./$(INCLUDE_DIR)
CFLAGS += -msmall-data-limit=8
CFLAGS += -std=gnu11
CFLAGS += -ffunction-sections
CFLAGS += -fdata-sections
CFLAGS += -g3
CFLAGS += --sysroot=$(SYSROOT)

# =============================================================================
# Linker flags
# -nostartfiles  : crt0.riscv.S is our startup, not the toolchain's
# -nodefaultlibs : no libgcc, no libc — bare metal, no libc available locally
# -lc removed    : not present in local LLVM build or server sysroot
# If undefined symbol errors appear (memcpy etc.), add -L path to libc.a
# once server access is restored, or add soft/memcpy_stub.c for the symbols.
# =============================================================================
LDFLAGS  = -fuse-ld=$(LD)
LDFLAGS += -Wl,--build-id=none
LDFLAGS += -Wl,-Map=$(OUTPUT_DIR)/aes.map
LDFLAGS += -Wl,--gc-sections
LDFLAGS += -T link.common.ld
LDFLAGS += --sysroot=$(SYSROOT)
LDFLAGS += -nostartfiles
LDFLAGS += -nodefaultlibs

# =============================================================================
# Sources
# =============================================================================
MAIN_SRC    := main.c
SOFT_SRC    := $(wildcard $(SOFT_DIR)/*.c)
ACC_SRC     := $(wildcard $(ACC_DIR)/*.S)
INCLUDE_SRC := $(wildcard $(INCLUDE_DIR)/*.c)

SOFT_OBJS := $(patsubst %.c,%.o,$(SOFT_SRC))   \
             $(patsubst %.c,%.o,$(INCLUDE_SRC)) \
             $(patsubst %.c,%.o,$(MAIN_SRC))

ACC_OBJS  := $(patsubst %.S,%.o,$(ACC_SRC))     \
             $(patsubst %.c,%.o,$(INCLUDE_SRC)) \
             $(patsubst %.c,%.o,$(MAIN_SRC))

PYTHON        := python3
SREC_TO_COE   := python_script/srec_to_coe.py
PY_FLAGS_CODE := -b 0x8000   -s 0x8000 -f
PY_FLAGS_DATA := -b 0x100000 -s 0x8000 -f

# =============================================================================
# Rules
# =============================================================================
.PHONY: all soft acc clean check

all: soft

# Sanity-check the toolchain before any build
check:
	@echo "LLVMCC  : $(LLVMCC)"
	@echo "OBJCOPY : $(OBJCOPY)"
	@echo "LD      : $(LD)"
	@echo "SYSROOT : $(SYSROOT)"
	@echo "ARCH    : $(ARCH)  ABI: $(ABI)"
	@$(LLVMCC) --version | head -1
	@echo "LD version:"; $(LD) --version | head -1

# crt0 — assembler only, minimal flags
crt0.riscv.o: crt0.riscv.S
	$(LLVMCC) --target=riscv32 -march=$(ARCH) -mabi=$(ABI) \
	          --sysroot=$(SYSROOT) \
	          -c -x assembler-with-cpp -o $@ $<

# C objects
%.o: %.c
	$(LLVMCC) $(CFLAGS) -c -o $@ $<

# Soft target (C only)
soft: $(SOFT_OBJS) crt0.riscv.o
	$(LLVMCC) $(CFLAGS) $(LDFLAGS) \
	          -o $(OUTPUT_DIR)/soft.elf $(SOFT_OBJS) crt0.riscv.o
	$(OBJCOPY) -O srec $(OUTPUT_DIR)/soft.elf $(OUTPUT_DIR)/soft.srec
	$(PYTHON) $(SREC_TO_COE) $(OUTPUT_DIR)/soft.srec $(PY_FLAGS_CODE) -o $(BIN_DIR)/code.coe
	$(PYTHON) $(SREC_TO_COE) $(OUTPUT_DIR)/soft.srec $(PY_FLAGS_DATA) -o $(BIN_DIR)/data.coe

# Acc target (C + assembly accelerator files)
acc: $(ACC_OBJS) crt0.riscv.o
	$(LLVMCC) $(CFLAGS) $(LDFLAGS) \
	          -o $(OUTPUT_DIR)/acc.elf $(ACC_OBJS) crt0.riscv.o
	$(OBJCOPY) -O srec $(OUTPUT_DIR)/acc.elf $(OUTPUT_DIR)/acc.srec
	$(PYTHON) $(SREC_TO_COE) $(OUTPUT_DIR)/acc.srec $(PY_FLAGS_CODE) -o $(BIN_DIR)/acc_code.coe
	$(PYTHON) $(SREC_TO_COE) $(OUTPUT_DIR)/acc.srec $(PY_FLAGS_DATA) -o $(BIN_DIR)/acc_data.coe

clean:
	rm -rf crt0.riscv.o $(OUTPUT_DIR) \
	       $(SOFT_OBJS) $(ACC_OBJS)
