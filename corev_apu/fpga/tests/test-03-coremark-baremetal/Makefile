RISCV_PREFIX ?= /home/carlos/tools/riscv64/bin/riscv64-unknown-elf-
CC := $(RISCV_PREFIX)gcc
OBJDUMP := $(RISCV_PREFIX)objdump
SIZE := $(RISCV_PREFIX)size

BUILD_DIR := build
ELF := $(BUILD_DIR)/coremark-baremetal.elf

COREMARK_DIR := ../../../../verif/tests/custom/coremark
COREMARK_BUILD_DIR := $(BUILD_DIR)/coremark-src
COREMARK_FILES := \
	coremark.h \
	coremark_main.c \
	core_list_join.c \
	core_matrix.c \
	core_state.c \
	core_util.c
COREMARK_SRCS := $(addprefix $(COREMARK_BUILD_DIR)/,$(filter %.c,$(COREMARK_FILES)))
LOCAL_SRCS := start.S core_portme.c uart_printf.c

CLOCK_HZ ?= 50000000
ITERATIONS ?= 2000
TOTAL_DATA_SIZE ?= 2000
CONFIG_STAMP := $(BUILD_DIR)/.config-iter$(ITERATIONS)-size$(TOTAL_DATA_SIZE)-hz$(CLOCK_HZ)

CFLAGS := -march=rv64imac -mabi=lp64 -mcmodel=medany -O3 -g -ffreestanding \
	-fno-builtin -fno-common -I. -I$(COREMARK_BUILD_DIR) \
	-DPERFORMANCE_RUN=1 -DITERATIONS=$(ITERATIONS) \
	-DTOTAL_DATA_SIZE=$(TOTAL_DATA_SIZE) -DCLOCK_HZ=$(CLOCK_HZ) \
	-DFLAGS_STR="\"-O3 -march=rv64imac -mabi=lp64 -mcmodel=medany\""
LDFLAGS := -nostdlib -nostartfiles -T linker.ld
LDLIBS := -lgcc

.PHONY: all clean disasm size

all: $(ELF)

$(BUILD_DIR):
	mkdir -p $@

$(CONFIG_STAMP): | $(BUILD_DIR)
	rm -f $(BUILD_DIR)/.config-*
	touch $@

$(COREMARK_BUILD_DIR): | $(BUILD_DIR)
	mkdir -p $@

$(COREMARK_BUILD_DIR)/%: $(COREMARK_DIR)/% | $(COREMARK_BUILD_DIR)
	cp $< $@

$(COREMARK_BUILD_DIR)/core_portme.h: core_portme.h | $(COREMARK_BUILD_DIR)
	cp $< $@

$(ELF): $(LOCAL_SRCS) $(COREMARK_SRCS) $(COREMARK_BUILD_DIR)/coremark.h $(COREMARK_BUILD_DIR)/core_portme.h linker.ld $(CONFIG_STAMP) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(LOCAL_SRCS) $(COREMARK_SRCS) $(LDLIBS)
	$(SIZE) $@

disasm: $(ELF)
	$(OBJDUMP) -d $<

size: $(ELF)
	$(SIZE) $<

clean:
	rm -rf $(BUILD_DIR)
