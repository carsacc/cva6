# ZCU111 BusyBox Initramfs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a ZCU111 Linux test that boots to a real BusyBox shell over UART.

**Architecture:** Keep BusyBox source outside the CVA6 fork under `/home/carlos/tools/busybox`. Store only board-specific scripts, init script, GDB loader, and documentation in this repo. Reuse the validated Linux/OpenSBI DTB and kernel fragment from the Linux smoke test, but build a separate initramfs containing static RISC-V BusyBox.

**Tech Stack:** BusyBox 1.36.1, Linux 6.6.y, `riscv64-linux-gnu-gcc`, OpenSBI `fw_jump`, GDB/OpenOCD, UART 8250 console.

---

## File Structure

- Create: `corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh`
  - Validate dependencies, build static BusyBox, create initramfs, rebuild Linux Image, and boot it through GDB.
- Create: `corev_apu/fpga/tests/test-11-busybox-initramfs/init`
  - PID 1 shell script that mounts `/dev`, `/proc`, `/sys`, prints a boot marker, and execs BusyBox `sh`.
- Create: `corev_apu/fpga/tests/test-11-busybox-initramfs/gdb-busybox-boot.gdb`
  - Load OpenSBI, Linux Image, and DTB at the validated addresses.
- Create: `corev_apu/fpga/tests/test-11-busybox-initramfs/README.md`
  - Document dependencies, command, expected UART output, and first shell commands.
- Modify: `corev_apu/fpga/tests/README.md`
  - Add `test-11-busybox-initramfs` to the test sequence.

## Task 1: Add BusyBox Test

- [ ] Add the `init` script that mounts `devtmpfs`, `devpts`, `proc`, and `sysfs`, redirects stdio to `/dev/console`, prints `CVA6 ZCU111 BusyBox initramfs reached`, and execs BusyBox shell.
- [ ] Add `run.sh` to build static BusyBox with `riscv64-linux-gnu-`, create `build/initramfs.cpio`, rebuild Linux Image with the same ZCU111 config fragment, and launch GDB.
- [ ] Add `gdb-busybox-boot.gdb` using the validated load addresses: OpenSBI at `0x80000000`, Linux at `0x80200000`, DTB at `0x82200000`.

## Task 2: Document and Verify

- [ ] Add README usage and expected `/ #` prompt.
- [ ] Update `corev_apu/fpga/tests/README.md`.
- [ ] Run `corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh --check-only`.
- [ ] Run `corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh` with OpenOCD and UART active.
- [ ] Verify UART reaches `CVA6 ZCU111 BusyBox initramfs reached` and a BusyBox shell prompt.
- [ ] Run `git diff --check`.
