RISCV_PREFIX ?= /home/carlos/tools/riscv64/bin/riscv64-unknown-elf-
CC := $(RISCV_PREFIX)gcc
OBJDUMP := $(RISCV_PREFIX)objdump

BUILD_DIR := build
ELF := $(BUILD_DIR)/uart-hello.elf

CFLAGS := -march=rv64imac -mabi=lp64 -mcmodel=medany -O2 -g -ffreestanding
LDFLAGS := -nostdlib -nostartfiles -T linker.ld

.PHONY: all clean disasm

all: $(ELF)

$(BUILD_DIR):
	mkdir -p $@

$(ELF): start.S linker.ld | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.S

disasm: $(ELF)
	$(OBJDUMP) -d $<

clean:
	rm -rf $(BUILD_DIR)
