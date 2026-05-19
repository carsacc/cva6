# ZCU111 OpenSBI Smoke Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first Linux-preparation test for the current ZCU111 DDR4 bitstream by booting OpenSBI from DDR through GDB/JTAG and confirming UART output plus a deterministic S-mode payload handoff.

**Architecture:** Keep the current FPGA image unchanged. Build OpenSBI externally from a local source tree under `~/tools` or an `OPENSBI_DIR` override, provide a ZCU111-specific DTB from this repo, embed a tiny S-mode payload into `fw_payload.elf`, then load and run it through the existing OpenOCD/GDB flow.

**Tech Stack:** CVA6 ZCU111 DDR4 bitstream, OpenOCD, `riscv64-unknown-elf-gcc`, `riscv64-unknown-elf-gdb`, OpenSBI `PLATFORM=generic`, `dtc`, UART `/dev/ttyUSB2` at 115200 8N1.

**Implementation note:** The local toolchain is `riscv64-unknown-elf-gcc`
11.1.0 with binutils 2.37. OpenSBI `master`/`v1.8` requires PIE support that
this linker does not provide, and OpenSBI `v1.4` uses `--exclude-libs`, which
this linker rejects. The smoke test is therefore pinned to OpenSBI `v1.3`.

---

## File Structure

- Modify: `corev_apu/fpga/tests/README.md`
  - Add the OpenSBI smoke test to the validated sequence and document UART expectations.
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/Makefile`
  - Build the DTB, S-mode payload, and OpenSBI `fw_payload.elf`.
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/zcu111-cva6.dts`
  - Describe the current hardware map: one hart, 1 GiB DDR at `0x80000000`, CLINT, PLIC, UART.
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/payload.S`
  - Tiny S-mode payload that prints a handoff message, writes a magic value in DDR, and spins.
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/payload.ld`
  - Link the payload at `0x80200000`, matching the default OpenSBI payload offset from `0x80000000`.
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/gdb-load-run.gdb`
  - Load OpenSBI, load the DTB at `0x82000000`, set `a0/a1/pc`, run to payload completion, and check the magic value.
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/run.sh`
  - Build and launch the GDB script with the current toolchain.

## Constants

- Core clock: `50 MHz`
- UART base: `0x10000000`
- UART divisor for 115200 at 50 MHz: `27`
- DRAM base: `0x80000000`
- DRAM size exposed by SoC map: `0x40000000`
- OpenSBI text address: `0x80000000`
- Payload address: `0x80200000`
- DTB load address: `0x82000000`
- Payload done magic address: `0x80300000`
- Payload done magic value: `0x4f534249444f4e45` (`OSBIDONE`)
- CLINT base: `0x02000000`
- CLINT size: `0x000c0000`
- CLINT timer frequency for current RTL: `25 MHz`, because `rtc` toggles every 50 MHz core cycle and the CLINT increments on `rtc` edges.
- PLIC base: `0x0c000000`
- PLIC size: `0x03ffffff`
- PLIC interrupt cells: `#interrupt-cells = <1>`
- UART interrupt source: use source `1` initially. If Linux/OpenSBI later shows interrupt issues, verify against `ariane_peripherals_xilinx.sv` and adjust.

## Task 1: Preserve DDR4 Checkpoint Before Linux Work

**Files:**
- No file changes.

- [ ] **Step 1: Check current branch and dirty state**

Run:

```bash
git status --short --branch
```

Expected:

```text
## zcu111-ddr4...origin/zcu111-ddr4 [ahead 1]
 M corev_apu/fpga/constraints/ariane.xdc
 M corev_apu/fpga/constraints/zcu111.xdc
 M corev_apu/fpga/scripts/run.tcl
 M corev_apu/fpga/src/ariane_xilinx.sv
```

- [ ] **Step 2: Review DDR4 timing/CDC diff**

Run:

```bash
git diff -- corev_apu/fpga/constraints/ariane.xdc corev_apu/fpga/constraints/zcu111.xdc corev_apu/fpga/scripts/run.tcl corev_apu/fpga/src/ariane_xilinx.sv
```

Expected: only the reset synchronizers, targeted CDC/reset constraints, and bitstream copy change are present.

- [ ] **Step 3: Create a checkpoint commit only after user approval**

Run only when approved:

```bash
git add corev_apu/fpga/constraints/ariane.xdc \
        corev_apu/fpga/constraints/zcu111.xdc \
        corev_apu/fpga/scripts/run.tcl \
        corev_apu/fpga/src/ariane_xilinx.sv
git commit -m "fix(fpga): synchronize zcu111 ddr reset timing"
```

Expected: a commit that captures the validated DDR4/timing state before OpenSBI work.

## Task 2: Add ZCU111 Device Tree for OpenSBI

**Files:**
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/zcu111-cva6.dts`

- [ ] **Step 1: Create the test directory**

Run:

```bash
mkdir -p corev_apu/fpga/tests/test-05-opensbi-smoke
```

Expected: directory exists.

- [ ] **Step 2: Add the DTS**

Create `corev_apu/fpga/tests/test-05-opensbi-smoke/zcu111-cva6.dts`:

```dts
/dts-v1/;

/ {
    #address-cells = <2>;
    #size-cells = <2>;
    compatible = "openhwgroup,cva6-zcu111", "riscv-virtio";
    model = "CVA6 ZCU111 DDR4";

    chosen {
        stdout-path = "serial0:115200n8";
    };

    cpus {
        #address-cells = <1>;
        #size-cells = <0>;
        timebase-frequency = <25000000>;

        cpu0: cpu@0 {
            device_type = "cpu";
            reg = <0>;
            status = "okay";
            compatible = "riscv";
            riscv,isa = "rv64imafdc";
            mmu-type = "riscv,sv39";

            cpu0_intc: interrupt-controller {
                #address-cells = <0>;
                #interrupt-cells = <1>;
                interrupt-controller;
                compatible = "riscv,cpu-intc";
            };
        };
    };

    memory@80000000 {
        device_type = "memory";
        reg = <0x0 0x80000000 0x0 0x40000000>;
    };

    soc {
        #address-cells = <2>;
        #size-cells = <2>;
        compatible = "simple-bus";
        ranges;

        clint0: clint@2000000 {
            compatible = "riscv,clint0";
            reg = <0x0 0x02000000 0x0 0x000c0000>;
            interrupts-extended = <&cpu0_intc 3>, <&cpu0_intc 7>;
        };

        plic0: interrupt-controller@c000000 {
            compatible = "riscv,plic0";
            reg = <0x0 0x0c000000 0x0 0x03ffffff>;
            #address-cells = <0>;
            #interrupt-cells = <1>;
            interrupt-controller;
            riscv,ndev = <30>;
            interrupts-extended = <&cpu0_intc 11>, <&cpu0_intc 9>;
        };

        serial0: serial@10000000 {
            compatible = "ns16550a";
            reg = <0x0 0x10000000 0x0 0x1000>;
            reg-shift = <2>;
            reg-io-width = <1>;
            clock-frequency = <50000000>;
            current-speed = <115200>;
            interrupts = <1>;
            interrupt-parent = <&plic0>;
        };
    };
};
```

- [ ] **Step 3: Validate DTS syntax**

Run:

```bash
dtc -I dts -O dtb -o /tmp/zcu111-cva6.dtb corev_apu/fpga/tests/test-05-opensbi-smoke/zcu111-cva6.dts
```

Expected: command exits with code 0. Warnings about default address/size cells are not expected because all buses define them.

## Task 3: Add Deterministic S-Mode Payload

**Files:**
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/payload.S`
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/payload.ld`

- [ ] **Step 1: Add payload assembly**

Create `corev_apu/fpga/tests/test-05-opensbi-smoke/payload.S`:

```asm
    .section .text
    .globl _start
_start:
    la sp, payload_stack_top
    call uart_init
    la a0, payload_msg
    call uart_puts

    li t0, 0x80300000
    li t1, 0x4f534249444f4e45
    sd t1, 0(t0)

payload_done:
    wfi
    j payload_done

uart_init:
    li t0, 0x10000004
    sb zero, 0(t0)
    li t0, 0x1000000c
    li t1, 0x80
    sb t1, 0(t0)
    li t0, 0x10000000
    li t1, 27
    sb t1, 0(t0)
    li t0, 0x10000004
    sb zero, 0(t0)
    li t0, 0x1000000c
    li t1, 0x03
    sb t1, 0(t0)
    li t0, 0x10000008
    li t1, 0x07
    sb t1, 0(t0)
    ret

uart_puts:
    mv t2, a0
1:
    lbu t3, 0(t2)
    beqz t3, 3f
2:
    li t0, 0x10000014
    lbu t1, 0(t0)
    andi t1, t1, 0x20
    beqz t1, 2b
    li t0, 0x10000000
    sb t3, 0(t0)
    addi t2, t2, 1
    j 1b
3:
    ret

    .section .rodata
payload_msg:
    .asciz "\r\nCVA6 ZCU111 OpenSBI S-mode payload reached\r\n"

    .section .bss
    .align 12
payload_stack:
    .space 4096
payload_stack_top:
```

- [ ] **Step 2: Add payload linker script**

Create `corev_apu/fpga/tests/test-05-opensbi-smoke/payload.ld`:

```ld
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  dram (rwx) : ORIGIN = 0x80200000, LENGTH = 1M
}

SECTIONS
{
  . = ORIGIN(dram);
  .text : { *(.text*) } > dram
  .rodata : { *(.rodata*) } > dram
  .data : { *(.data*) } > dram
  .bss : {
    *(.bss*)
    *(COMMON)
  } > dram
}
```

## Task 4: Add Build Script for DTB, Payload, and OpenSBI

**Files:**
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/Makefile`

- [ ] **Step 1: Add Makefile**

Create `corev_apu/fpga/tests/test-05-opensbi-smoke/Makefile`:

```make
RISCV_PREFIX ?= /home/carlos/tools/riscv64/bin/riscv64-unknown-elf-
CC := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy

OPENSBI_DIR ?= /home/carlos/tools/opensbi
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

$(BUILD_DIR):
	mkdir -p $@

$(DTB): zcu111-cva6.dts | $(BUILD_DIR)
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
	  FW_TEXT_START=$(FW_TEXT_START) \
	  FW_PAYLOAD_OFFSET=$(FW_PAYLOAD_OFFSET) \
	  FW_PAYLOAD_PATH="$(PAYLOAD_BIN)" \
	  FW_FDT_PATH="$(DTB)"

clean:
	rm -rf $(BUILD_DIR)
```

- [ ] **Step 2: Run without OpenSBI source to check error handling**

Run only if `/home/carlos/tools/opensbi` is absent:

```bash
make -C corev_apu/fpga/tests/test-05-opensbi-smoke all
```

Expected:

```text
ERROR: OPENSBI_DIR='/home/carlos/tools/opensbi' does not look like an OpenSBI source tree.
Clone OpenSBI to /home/carlos/tools/opensbi or run with OPENSBI_DIR=/path/to/opensbi.
```

## Task 5: Obtain OpenSBI Source

**Files:**
- External source directory: `/home/carlos/tools/opensbi`

- [ ] **Step 1: Clone OpenSBI outside the CVA6 repo**

Run:

```bash
cd /home/carlos/tools
git clone https://github.com/riscv-software-src/opensbi.git opensbi
cd opensbi
git status --short --branch
```

Expected: OpenSBI source exists at `/home/carlos/tools/opensbi`. This keeps third-party source out of the CVA6 fork.

- [ ] **Step 2: Record the OpenSBI commit**

Run:

```bash
cd /home/carlos/tools/opensbi
git rev-parse --short HEAD
```

Expected: a short commit hash to copy into the test README after the first successful run.

## Task 6: Add GDB and Run Scripts

**Files:**
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/gdb-load-run.gdb`
- Create: `corev_apu/fpga/tests/test-05-opensbi-smoke/run.sh`

- [ ] **Step 1: Add GDB script**

Create `corev_apu/fpga/tests/test-05-opensbi-smoke/gdb-load-run.gdb`:

```gdb
set pagination off
set confirm off
set architecture riscv:rv64

file build/opensbi/platform/generic/firmware/fw_payload.elf
add-symbol-file build/payload.elf 0x80200000

target extended-remote localhost:3333
monitor halt
monitor riscv dmi_write 0x10 0x00000001

load
restore build/zcu111-cva6.dtb binary 0x82000000

set $a0 = 0
set $a1 = 0x82000000
set $pc = 0x80000000
set $dpc = 0x80000000

break payload_done
continue

set $done = *(unsigned long long *)0x80300000
if $done != 0x4f534249444f4e45
  printf "FAIL: OpenSBI payload magic = 0x%016lx\n", $done
  detach
  quit 1
end

printf "PASS: OpenSBI reached S-mode payload and wrote OSBIDONE magic\n"
printf "Check UART for OpenSBI banner and: CVA6 ZCU111 OpenSBI S-mode payload reached\n"
info registers pc a0 a1 mhartid mstatus misa
x/gx 0x80300000

detach
quit
```

- [ ] **Step 2: Add run script**

Create `corev_apu/fpga/tests/test-05-opensbi-smoke/run.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GDB="${RISCV_GDB:-/home/carlos/tools/riscv64/bin/riscv64-unknown-elf-gdb}"

make -C "${SCRIPT_DIR}" all
cd "${SCRIPT_DIR}"
exec "${GDB}" -q -batch -x gdb-load-run.gdb
```

- [ ] **Step 3: Make script executable**

Run:

```bash
chmod +x corev_apu/fpga/tests/test-05-opensbi-smoke/run.sh
```

Expected: executable bit set.

## Task 7: Build and Run OpenSBI Smoke

**Files:**
- Uses files created in Tasks 2-6.

- [ ] **Step 1: Build test artifacts**

Run:

```bash
make -C corev_apu/fpga/tests/test-05-opensbi-smoke clean
make -C corev_apu/fpga/tests/test-05-opensbi-smoke all
```

Expected artifacts:

```text
corev_apu/fpga/tests/test-05-opensbi-smoke/build/zcu111-cva6.dtb
corev_apu/fpga/tests/test-05-opensbi-smoke/build/payload.elf
corev_apu/fpga/tests/test-05-opensbi-smoke/build/payload.bin
corev_apu/fpga/tests/test-05-opensbi-smoke/build/opensbi/platform/generic/firmware/fw_payload.elf
```

- [ ] **Step 2: Start OpenOCD**

Run in terminal 1:

```bash
corev_apu/fpga/tests/run-openocd-zcu111.sh
```

Expected: OpenOCD listens on GDB port `3333`.

- [ ] **Step 3: Start UART terminal**

Run in terminal 2:

```bash
picocom -b 115200 /dev/ttyUSB2
```

Expected: terminal opens. If using CuteCom, configure `/dev/ttyUSB2`, `115200`, `8N1`.

- [ ] **Step 4: Run OpenSBI smoke**

Run in terminal 3:

```bash
corev_apu/fpga/tests/test-05-opensbi-smoke/run.sh
```

Expected GDB output includes:

```text
Breakpoint 1, payload_done ()
PASS: OpenSBI reached S-mode payload and wrote OSBIDONE magic
0x80300000: 0x4f534249444f4e45
```

Expected UART output includes:

```text
OpenSBI
CVA6 ZCU111 OpenSBI S-mode payload reached
```

## Task 8: Update Test README

**Files:**
- Modify: `corev_apu/fpga/tests/README.md`

- [ ] **Step 1: Replace planned `test-05-timer-interrupts` line**

Change the planned sequence item 6 to:

```markdown
6. `test-05-opensbi-smoke`: boot OpenSBI from PL DDR4 through GDB/JTAG,
   pass the ZCU111 DTB, and confirm handoff to a tiny S-mode payload.
```

- [ ] **Step 2: Add OpenSBI usage section**

Append:

````markdown
For `test-05-opensbi-smoke`, keep OpenSBI outside this fork. The default source
location is `/home/carlos/tools/opensbi`; override it with `OPENSBI_DIR` if
needed. Open a UART terminal on `/dev/ttyUSB2` at 115200 8N1, keep OpenOCD
running, then launch:

```sh
corev_apu/fpga/tests/test-05-opensbi-smoke/run.sh
```

The GDB script loads `fw_payload.elf` at `0x80000000`, loads the DTB at
`0x82000000`, passes `a0=0` and `a1=0x82000000`, and checks that the S-mode
payload writes `0x4f534249444f4e45` at `0x80300000`.
````

## Task 9: Verification and Checkpoint

**Files:**
- All files touched by this plan.

- [ ] **Step 1: Run static checks**

Run:

```bash
git diff --check
dtc -I dts -O dtb -o /tmp/zcu111-cva6.dtb corev_apu/fpga/tests/test-05-opensbi-smoke/zcu111-cva6.dts
```

Expected: both commands exit with code 0.

- [ ] **Step 2: Run regression smoke tests**

With OpenOCD running and the current DDR4 bitstream programmed, run:

```bash
corev_apu/fpga/tests/test-00-gdb-smoke/run.sh
corev_apu/fpga/tests/test-02-uart/run.sh
corev_apu/fpga/tests/test-04-ddr4-baremetal/run.sh
corev_apu/fpga/tests/test-05-opensbi-smoke/run.sh
```

Expected: all GDB scripts print `PASS`.

- [ ] **Step 3: Review repo state**

Run:

```bash
git status --short
```

Expected: only intended files are modified or created.

- [ ] **Step 4: Commit only after user approval**

Run only when approved:

```bash
git add corev_apu/fpga/tests/README.md \
        corev_apu/fpga/tests/test-05-opensbi-smoke
git commit -m "test(fpga): add zcu111 opensbi smoke"
```

Expected: a separate OpenSBI test commit after the DDR4 checkpoint commit.

## Self-Review

- Spec coverage: The plan covers checkpointing the validated DDR4 state, building OpenSBI outside the fork, adding a ZCU111 DTB, adding a deterministic S-mode payload, loading through GDB, verifying UART output and memory magic, and documenting usage.
- Placeholder scan: No TBD/TODO placeholders remain. All paths, addresses, commands, and expected outputs are explicit.
- Type and symbol consistency: `payload_done`, `0x80200000`, `0x82000000`, `0x80300000`, and `0x4f534249444f4e45` are used consistently across payload, Makefile, and GDB script.
