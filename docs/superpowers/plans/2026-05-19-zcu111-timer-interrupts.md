# ZCU111 Timer Interrupts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a repeatable ZCU111 Linux-preparation test that proves OpenSBI can deliver a CLINT timer interrupt to an S-mode payload.

**Architecture:** Reuse the current DDR4 bitstream and the OpenSBI `fw_payload` flow validated by `test-05-opensbi-smoke`. The new payload runs in S-mode, installs an S-mode trap vector, schedules a timer through the SBI TIME extension, waits for `STIP`, writes a deterministic DDR magic value, and stops in a GDB-visible loop.

**Tech Stack:** CVA6 ZCU111 DDR4 bitstream, OpenSBI v1.3 `PLATFORM=generic`, `riscv64-unknown-elf-gcc`, OpenOCD/GDB, CLINT timer, UART `/dev/ttyUSB2` at 115200 8N1.

---

## File Structure

- Create: `corev_apu/fpga/tests/test-06-timer-interrupts/Makefile`
  - Build the S-mode timer payload and OpenSBI `fw_payload.elf`, reusing the ZCU111 DTS and OpenSBI defconfig from `test-05`.
- Create: `corev_apu/fpga/tests/test-06-timer-interrupts/payload.S`
  - S-mode test payload. It prints a start message, installs `stvec`, calls `SBI_EXT_TIME.SET_TIMER`, enables `STIE/SIE`, handles the timer interrupt, writes `TIMEROK!` to DDR, and spins.
- Create: `corev_apu/fpga/tests/test-06-timer-interrupts/payload.ld`
  - Link the payload at `0x80200000`.
- Create: `corev_apu/fpga/tests/test-06-timer-interrupts/gdb-load-run.gdb`
  - Load OpenSBI and the DTB, run to `timer_done`, and verify `0x80301000 == 0x54494d45524f4b21`.
- Create: `corev_apu/fpga/tests/test-06-timer-interrupts/run.sh`
  - Build and run the GDB script.
- Modify: `corev_apu/fpga/tests/README.md`
  - Add the new test to quick start and document expected UART/GDB output.

## Constants

- OpenSBI text address: `0x80000000`
- Payload address: `0x80200000`
- DTB load address: `0x82000000`
- Timer result address: `0x80301000`
- Timer pass magic: `0x54494d45524f4b21` (`TIMEROK!`)
- Timer fail magic: `0x54494d4552464149` (`TIMERFAI`)
- SBI TIME extension ID: `0x54494d45`
- SBI SET_TIMER function ID: `0`
- Timer delta: `250000` CLINT ticks, approximately 10 ms at the validated 25 MHz timer rate.

## Task 1: Add Timer Payload Test Files

**Files:**
- Create: `corev_apu/fpga/tests/test-06-timer-interrupts/Makefile`
- Create: `corev_apu/fpga/tests/test-06-timer-interrupts/payload.S`
- Create: `corev_apu/fpga/tests/test-06-timer-interrupts/payload.ld`
- Create: `corev_apu/fpga/tests/test-06-timer-interrupts/gdb-load-run.gdb`
- Create: `corev_apu/fpga/tests/test-06-timer-interrupts/run.sh`

- [ ] **Step 1: Create the test files**

Add the files listed above. The Makefile must reuse:

```make
COMMON_DIR := $(abspath $(CURDIR)/../test-05-opensbi-smoke)
DTS := $(COMMON_DIR)/zcu111-cva6.dts
OPENSBI_PLATFORM_DEFCONFIG ?= $(shell realpath --relative-to="$(OPENSBI_DIR)/platform/generic/configs" "$(COMMON_DIR)/opensbi-zcu111_defconfig")
```

Expected: `make -C corev_apu/fpga/tests/test-06-timer-interrupts all` can build without duplicating the DTS or defconfig.

- [ ] **Step 2: Verify the S-mode payload mechanics**

The payload must align the trap handler to a 4-byte boundary because `stvec`
stores a BASE field with the low two bits reserved:

```asm
csrw stvec, trap_handler
csrr a0, time
addi-or-add a0, a0, TIMER_DELTA
li a7, 0x54494d45
li a6, 0
ecall
csrs sie, 0x20
csrsi sstatus, 0x2
```

Expected: the handler receives `scause == 0x8000000000000005`, disables `STIE`, writes `TIMEROK!`, and branches to `timer_done`.

## Task 2: Build and Hardware-Run the Test

**Files:**
- Test: `corev_apu/fpga/tests/test-06-timer-interrupts/run.sh`

- [ ] **Step 1: Build cleanly**

Run:

```bash
make -C corev_apu/fpga/tests/test-06-timer-interrupts clean all
```

Expected: `fw_payload.elf`, payload ELF, payload binary, and DTB are generated under ignored `build/`.

- [ ] **Step 2: Run through OpenOCD/GDB**

With OpenOCD already running:

```bash
corev_apu/fpga/tests/test-06-timer-interrupts/run.sh
```

Expected GDB output:

```text
PASS: S-mode timer interrupt fired and wrote TIMEROK magic
0x80301000: 0x54494d45524f4b21
```

Expected UART output includes:

```text
CVA6 ZCU111 S-mode timer interrupt test
S-mode timer interrupt fired
```

## Task 3: Document the Validated Test

**Files:**
- Modify: `corev_apu/fpga/tests/README.md`

- [ ] **Step 1: Update the planned sequence**

Replace the planned timer line with:

```text
7. `test-06-timer-interrupts`: validate OpenSBI timer delivery to S-mode through the CLINT before attempting Linux.
```

- [ ] **Step 2: Add quick-start command**

Add:

```sh
corev_apu/fpga/tests/test-06-timer-interrupts/run.sh
```

- [ ] **Step 3: Add expected output section**

Document the UART and GDB pass strings from Task 2.

## Task 4: Final Verification

**Files:**
- All files touched by this plan.

- [ ] **Step 1: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 2: Review status**

Run:

```bash
git status --short --branch
```

Expected: only `test-06` files, README, and this plan are modified/untracked.
