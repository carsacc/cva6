# ZCU111 FPGA Tests

This directory contains repeatable tests for the CVA6 ZCU111 FPGA bring-up.

Planned test sequence:

1. `test-00-gdb-smoke`: OpenOCD/GDB connectivity, register reads, disassembly,
   and single-step.
2. `test-01-baremetal-iram`: load and run a minimal bare-metal ELF from
   internal RAM.
3. `test-02-uart`: validate UART TX/RX through the PMOD programmer.
4. `test-03-coremark-baremetal`: run CoreMark from the current PL DDR4
   implementation and print results through UART.
5. `test-04-ddr4-baremetal`: validate DDR4 memory read/write patterns from
   bare-metal code.
6. `test-05-timer-interrupts`: validate timer, traps, and basic interrupt
   handling before attempting Linux.

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
```

The current ZCU111 DDR4 build maps the SoC DRAM window at `0x8000_0000` to
the PL DDR4 controller. The test ELFs are loaded at `0x8000_0000`; the DDR4
memory test starts its destructive checks at `0x8010_0000` to avoid
overwriting the running program and stack.

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
