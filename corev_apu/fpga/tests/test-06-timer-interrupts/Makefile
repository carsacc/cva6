RISCV_PREFIX ?= /home/carlos/tools/riscv64/bin/riscv64-unknown-elf-
CC := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy

COMMON_DIR := $(abspath $(CURDIR)/../test-05-opensbi-smoke)
DTS := $(COMMON_DIR)/zcu111-cva6.dts

OPENSBI_DIR ?= /home/carlos/tools/opensbi
OPENSBI_REF ?= v1.3
OPENSBI_PLATFORM_DEFCONFIG ?= $(shell realpath --relative-to="$(OPENSBI_DIR)/platform/generic/configs" "$(COMMON_DIR)/opensbi-zcu111_defconfig")
OPENSBI_BUILD := $(CURDIR)/build/opensbi
BUILD_DIR := $(CURDIR)/build

FW_TEXT_START := 0x80000000
FW_PAYLOAD_OFFSET := 0x200000

PAYLOAD_ELF := $(BUILD_DIR)/payload.elf
PAYLOAD_BIN := $(BUILD_DIR)/payload.bin
DTB := $(BUILD_DIR)/zcu111-cva6.dtb
FW_PAYLOAD_ELF := $(OPENSBI_BUILD)/platform/generic/firmware/fw_payload.elf

.PHONY: all clean check-opensbi

all: $(FW_PAYLOAD_ELF) $(DTB) $(PAYLOAD_ELF)

check-opensbi:
	@test -f "$(OPENSBI_DIR)/Makefile" || { \
	  echo "ERROR: OPENSBI_DIR='$(OPENSBI_DIR)' does not look like an OpenSBI source tree."; \
	  echo "Clone OpenSBI to /home/carlos/tools/opensbi or run with OPENSBI_DIR=/path/to/opensbi."; \
	  exit 1; \
	}
	@if git -C "$(OPENSBI_DIR)" rev-parse --git-dir >/dev/null 2>&1; then \
	  ref="$$(git -C "$(OPENSBI_DIR)" describe --tags --always --dirty)"; \
	  test "$$ref" = "$(OPENSBI_REF)" || { \
	    echo "ERROR: OpenSBI checkout is '$$ref', expected '$(OPENSBI_REF)'."; \
	    echo "This test is pinned to OpenSBI $(OPENSBI_REF) for compatibility with /home/carlos/tools/riscv64."; \
	    echo "Run: git -C $(OPENSBI_DIR) checkout $(OPENSBI_REF)"; \
	    exit 1; \
	  }; \
	fi

$(BUILD_DIR):
	mkdir -p $@

$(DTB): $(DTS) | $(BUILD_DIR)
	dtc -I dts -O dtb -o $@ $<

$(PAYLOAD_ELF): payload.S payload.ld | $(BUILD_DIR)
	$(CC) -march=rv64imac -mabi=lp64 -mcmodel=medany -nostdlib -nostartfiles \
	  -T payload.ld -Wl,--build-id=none -o $@ payload.S

$(PAYLOAD_BIN): $(PAYLOAD_ELF)
	$(OBJCOPY) -O binary $< $@

$(FW_PAYLOAD_ELF): check-opensbi $(PAYLOAD_BIN) $(DTB)
	$(MAKE) -C "$(OPENSBI_DIR)" \
	  O="$(OPENSBI_BUILD)" \
	  CROSS_COMPILE="$(RISCV_PREFIX)" \
	  PLATFORM=generic \
	  PLATFORM_DEFCONFIG="$(OPENSBI_PLATFORM_DEFCONFIG)" \
	  FW_TEXT_START=$(FW_TEXT_START) \
	  FW_PAYLOAD_OFFSET=$(FW_PAYLOAD_OFFSET) \
	  FW_PAYLOAD_PATH="$(PAYLOAD_BIN)" \
	  FW_FDT_PATH="$(DTB)"

clean:
	rm -rf $(BUILD_DIR)
