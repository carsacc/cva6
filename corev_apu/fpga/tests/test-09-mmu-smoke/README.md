# ZCU111 S-mode MMU Smoke Test

This test isolates the Linux boot failure around early MMU enable. It boots a
small S-mode payload through OpenSBI, builds a minimal Sv39 root page table,
enables `satp`, and verifies both data and instruction access through a high
virtual alias.

Mappings:

```text
VA 0x0000000000000000 -> PA 0x0000000000000000  1 GiB, UART identity window
VA 0x0000000080000000 -> PA 0x0000000080000000  1 GiB, DDR identity window
VA 0xffffffff80000000 -> PA 0x0000000080000000  1 GiB, Linux-style high alias
```

Run with OpenOCD active and UART open on `/dev/ttyUSB2` at 115200 8N1:

```sh
corev_apu/fpga/tests/test-09-mmu-smoke/run.sh
```

Expected GDB output:

```text
PASS: S-mode Sv39 MMU smoke reached high-VA code and wrote MMUOK magic
```

Expected UART output:

```text
CVA6 ZCU111 S-mode Sv39 MMU smoke
S-mode Sv39 MMU smoke passed
```
