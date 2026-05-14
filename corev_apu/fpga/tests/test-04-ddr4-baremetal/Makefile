RISCV_PREFIX ?= /home/carlos/tools/riscv64/bin/riscv64-unknown-elf-
CC := $(RISCV_PREFIX)gcc
SIZE := $(RISCV_PREFIX)size
OBJDUMP := $(RISCV_PREFIX)objdump

BUILD_DIR := build
ELF := $(BUILD_DIR)/ddr4-baremetal.elf

TEST_BYTES ?= 16777216
TEST_STRIDE_BYTES ?= 64
CONTIG_BYTES ?= 262144
CLOCK_HZ ?= 50000000
CONFIG_STAMP := $(BUILD_DIR)/.config-bytes$(TEST_BYTES)-stride$(TEST_STRIDE_BYTES)-contig$(CONTIG_BYTES)-hz$(CLOCK_HZ)

CFLAGS := -march=rv64imac -mabi=lp64 -mcmodel=medany -O2 -g -ffreestanding \
	-fno-builtin -fno-common \
	-DDDR4_TEST_BYTES=$(TEST_BYTES) \
	-DDDR4_TEST_STRIDE_BYTES=$(TEST_STRIDE_BYTES) \
	-DDDR4_CONTIG_BYTES=$(CONTIG_BYTES) \
	-DCLOCK_HZ=$(CLOCK_HZ)
LDFLAGS := -nostdlib -nostartfiles -T linker.ld
LDLIBS := -lgcc

.PHONY: all clean disasm size

all: $(ELF)

$(BUILD_DIR):
	mkdir -p $@

$(CONFIG_STAMP): | $(BUILD_DIR)
	rm -f $(BUILD_DIR)/.config-*
	touch $@

$(ELF): start.S main.c ../test-03-coremark-baremetal/uart_printf.c linker.ld $(CONFIG_STAMP) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.S main.c ../test-03-coremark-baremetal/uart_printf.c $(LDLIBS)
	$(SIZE) $@

disasm: $(ELF)
	$(OBJDUMP) -d -S $<

size: $(ELF)
	$(SIZE) $<

clean:
	rm -rf $(BUILD_DIR)
