# ZCU111 FPGA Tests

This directory contains repeatable tests for the CVA6 ZCU111 FPGA bring-up.

Current validated hardware state:

- CVA6 core clock: 50 MHz.
- PL DDR4 controller: DDR4-2400 class, 64-bit physical bus, 512-bit AXI UI at
  300 MHz.
- UART: `/dev/ttyUSB2`, 115200 8N1, through the X-HEEP programmer PMOD_1.
- OpenOCD/JTAG: X-HEEP programmer PMOD_1 connected to ZCU111 PMOD_1/J49.
- DDR4 validation: `test-04-ddr4-baremetal` has passed with
  `TEST_BYTES=536870912`.

Planned test sequence:

1. `test-00-gdb-smoke`: OpenOCD/GDB connectivity, register reads, disassembly,
   and single-step.
2. `test-01-baremetal-iram`: load and run a minimal bare-metal ELF. The name
   is historical; on the DDR4 branch the ELF is loaded at the DDR window base.
3. `test-02-uart`: validate UART TX/RX through the PMOD programmer.
4. `test-03-coremark-baremetal`: run CoreMark from the current PL DDR4
   implementation and print results through UART.
5. `test-04-ddr4-baremetal`: validate DDR4 memory read/write patterns from
   bare-metal code.
6. `test-05-opensbi-smoke`: boot OpenSBI from DDR4, hand off to a tiny S-mode
   payload, print through UART, and verify a deterministic DDR magic value.
7. `test-06-timer-interrupts`: validate OpenSBI timer delivery to S-mode
   through the CLINT before attempting Linux.
8. `test-07-linux-build`: build minimal Linux `Image`, DTB, and initramfs
   artifacts for the ZCU111 DDR4/OpenSBI platform.
9. `test-08-linux-boot-smoke`: load OpenSBI `fw_jump`, Linux, and DTB through
   GDB/OpenOCD and validate the first Linux boot through UART.
10. `test-09-mmu-smoke`: isolate S-mode Sv39 translation before debugging the
    Linux early-MMU path further.
11. `test-10-linux-early-debug`: instrument Linux early boot with GDB
    breakpoints around `setup_vm()` and `relocate_enable_mmu()`.
12. `test-11-busybox-initramfs`: boot Linux with a static BusyBox initramfs and
    provide an interactive shell on UART.

OpenOCD configuration for the current hardware setup:

```sh
openocd -f corev_apu/fpga/zcu111-pmod.cfg
```

Quick start:

```sh
# Terminal 1
corev_apu/fpga/tests/run-openocd-zcu111.sh

# Terminal 2
corev_apu/fpga/tests/test-00-gdb-smoke/run.sh
corev_apu/fpga/tests/test-01-baremetal-iram/run.sh
corev_apu/fpga/tests/test-02-uart/run.sh
corev_apu/fpga/tests/test-03-coremark-baremetal/run.sh
corev_apu/fpga/tests/test-04-ddr4-baremetal/run.sh
corev_apu/fpga/tests/test-05-opensbi-smoke/run.sh
corev_apu/fpga/tests/test-06-timer-interrupts/run.sh
corev_apu/fpga/tests/test-07-linux-build/run.sh
corev_apu/fpga/tests/test-08-linux-boot-smoke/run.sh
corev_apu/fpga/tests/test-09-mmu-smoke/run.sh
corev_apu/fpga/tests/test-10-linux-early-debug/run.sh
corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh
```

The current ZCU111 DDR4 build maps the SoC DRAM window at `0x8000_0000` to
the PL DDR4 controller. The exposed SoC DRAM window is currently 1 GiB:
`0x8000_0000` through `0xbfff_ffff`. The test ELFs are loaded at
`0x8000_0000`; the DDR4 memory test starts its destructive checks at
`0x8010_0000` to avoid overwriting the running program and stack.

For `test-03-coremark-baremetal`, open the UART terminal on `/dev/ttyUSB2` at
115200 8N1 before launching the GDB script. The default build uses
`ITERATIONS=2000` and `CLOCK_HZ=50000000`; override them from the environment
if the CoreMark time check reports that the run is too short. The port uses
`mcycle` and prints time/throughput with decimal precision, without linking a
standard C library.

```sh
ITERATIONS=20 corev_apu/fpga/tests/test-03-coremark-baremetal/run.sh
ITERATIONS=2000 corev_apu/fpga/tests/test-03-coremark-baremetal/run.sh
```

For `test-04-ddr4-baremetal`, the default sweep writes and reads one 64-bit
word per 64-byte cache line over 16 MiB, then checks a 256 KiB contiguous
window and a small byte-lane window. The defaults can be reduced for quick
debug runs:

```sh
TEST_BYTES=1048576 CONTIG_BYTES=65536 corev_apu/fpga/tests/test-04-ddr4-baremetal/run.sh
```

The largest safe `TEST_BYTES` value with the current linker/test layout is
`1072693248`, which sweeps from `0x8010_0000` up to the end of the 1 GiB
window. A 512 MiB sweep has already been validated:

```sh
TEST_BYTES=536870912 corev_apu/fpga/tests/test-04-ddr4-baremetal/run.sh
```

For `test-05-opensbi-smoke`, keep the UART terminal open on `/dev/ttyUSB2` at
115200 8N1. The test builds a tiny S-mode payload at `0x8020_0000`, builds
OpenSBI `fw_payload.elf` at `0x8000_0000`, loads the DTB at `0x8200_0000`,
and verifies that the payload wrote `OSBIDONE` to `0x8030_0000`. The OpenSBI
build uses a local `opensbi-zcu111_defconfig` so semihosting is disabled and
console output goes through the DTB-described UART.

The OpenSBI source tree is external to this repo and is currently pinned to
`v1.3` because the local `riscv64-unknown-elf` binutils 2.37 rejects flags used
by newer OpenSBI releases.

```sh
git clone https://github.com/riscv-software-src/opensbi.git /home/carlos/tools/opensbi
git -C /home/carlos/tools/opensbi checkout v1.3
corev_apu/fpga/tests/test-05-opensbi-smoke/run.sh
```

Expected UART output includes the OpenSBI banner followed by:

```text
CVA6 ZCU111 OpenSBI S-mode payload reached
```

For `test-06-timer-interrupts`, keep OpenOCD running and the UART terminal open
on `/dev/ttyUSB2`. The test reuses the OpenSBI/DTB flow from `test-05`, but
the S-mode payload installs `stvec`, calls `SBI_EXT_TIME.SET_TIMER`, enables
`STIE/SIE`, and waits for a supervisor timer interrupt. GDB verifies that the
handler wrote `TIMEROK!` to `0x8030_1000`.

Expected GDB output includes:

```text
PASS: S-mode timer interrupt fired and wrote TIMEROK magic
0x80301000:     0x54494d45524f4b21
```

Expected UART output includes:

```text
CVA6 ZCU111 S-mode timer interrupt test
S-mode timer interrupt fired
```

For `test-07-linux-build`, Linux source is kept outside this fork at
`/home/carlos/tools/linux`. The test builds a small RISC-V Linux `Image`, a
ZCU111 DTB, and a tiny static initramfs from `allnoconfig` plus the local
fragment. These artifacts are used by the next hardware boot test.

```sh
git clone --depth 1 --branch linux-6.6.y https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git /home/carlos/tools/linux
corev_apu/fpga/tests/test-07-linux-build/run.sh
```

For `test-08-linux-boot-smoke`, keep OpenOCD running and the UART terminal open
on `/dev/ttyUSB2`. The test loads OpenSBI `fw_jump.elf` at `0x8000_0000`, Linux
`Image` at `0x8020_0000`, and the Linux DTB at `0x8220_0000`. GDB lets the
target run for a short boot window, then interrupts it and prints a register
snapshot. The pass/fail signal for now is UART output.

Expected UART output includes:

```text
CVA6 ZCU111 Linux initramfs reached
```

For `test-09-mmu-smoke`, keep OpenOCD running and the UART terminal open on
`/dev/ttyUSB2`. The test builds a minimal Sv39 root page table in S-mode,
identity maps UART/DDR, maps a Linux-style high virtual alias for DDR, enables
`satp`, verifies a high-VA data store, and jumps to code through the high alias.

Expected GDB output includes:

```text
PASS: S-mode Sv39 MMU smoke reached high-VA code and wrote MMUOK magic
```

For `test-10-linux-early-debug`, keep OpenOCD running. The test reloads the
same Linux artifacts as `test-08`, adds `vmlinux` symbols, and records the
state at the early boot milestones. It is a diagnostic script: reaching
`start_kernel` is success, while reaching the Linux park loop or OpenSBI trap
hang is treated as a failure with CSR and page-table dumps.

For `test-11-busybox-initramfs`, keep OpenOCD running and the UART terminal
open on `/dev/ttyUSB2`. `picocom -b 115200 /dev/ttyUSB2` is preferred because it
interprets BusyBox ANSI color escapes correctly. The test builds static RISC-V
BusyBox from the external source tree at `/home/carlos/tools/busybox`, embeds
it in a Linux initramfs, adds manually-run `/root/coremark`, `/root/memstress`,
`/root/mmio-test`, and `/root/irq-test` binaries, and boots to a real shell
over UART.

```sh
git clone --depth 1 --branch 1_36_1 https://git.busybox.net/busybox /home/carlos/tools/busybox
corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh
```

Expected UART output includes:

```text
CVA6 ZCU111 BusyBox initramfs reached
~ #
```

CoreMark is not executed automatically. Run it manually from the shell:

```sh
cd /root
./coremark
./memstress 256M
./mmio-test
./irq-test
```

The CoreMark Linux port reads the RISC-V `cycle` counter and assumes the current
50 MHz CVA6 clock for the `CoreMark/MHz` line. Override that assumption when
building with `COREMARK_CLOCK_HZ=<hz>`.

`mmio-test` validates the first ZCU111 PL peripheral window at `0x50000000`.
It checks the read-only ID/version registers, scratch read/write register, and
free-running counter. Expected completion line:

```text
PASS: PL peripheral MMIO test completed
```

`irq-test` validates the same PL peripheral through Linux UIO. It expects
`/dev/uio0`, triggers the PL interrupt twice, waits for both interrupt events,
acks the device-side status bit, and re-enables the UIO interrupt line. Expected
completion line:

```text
PASS: PL peripheral IRQ test completed
```
