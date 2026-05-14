# ZCU111 FPGA Tests

This directory contains repeatable tests for the CVA6 ZCU111 FPGA bring-up.

Planned test sequence:

1. `test-00-gdb-smoke`: OpenOCD/GDB connectivity, register reads, disassembly,
   and single-step.
2. `test-01-baremetal-iram`: load and run a minimal bare-metal ELF from
   internal RAM.
3. `test-02-uart`: validate UART TX/RX through the PMOD programmer.
4. `test-03-coremark-baremetal`: run CoreMark from the current 1 MiB local
   SRAM implementation and print results through UART.
5. `test-04-ddr4`: validate DDR4 status and memory read/write patterns from
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
```

The current ZCU111 build maps the SoC DRAM window at `0x8000_0000` to a
1 MiB local FPGA SRAM. DDR4 is not part of these tests yet.

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
