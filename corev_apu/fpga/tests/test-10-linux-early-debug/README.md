# ZCU111 Linux Early Debug Test

This test debugs the early Linux boot path around `setup_vm()` and
`relocate_enable_mmu`. It loads OpenSBI `fw_jump.elf`, the Linux `Image`, and
the ZCU111 Linux DTB through GDB/OpenOCD, then sets physical breakpoints on
early Linux code before continuing.

This is a GDB diagnostic, not the final UART boot validation. UART may only show
the OpenSBI banner while GDB is stopping the core at early Linux breakpoints. Use
`test-08-linux-boot-smoke` when the goal is to leave Linux running and watch for
the initramfs success line on UART.

Run with OpenOCD active and UART open on `/dev/ttyUSB2` at 115200 8N1:

```sh
corev_apu/fpga/tests/test-10-linux-early-debug/run.sh
```

The terminal running this script prints snapshots at:

```text
_start_kernel
setup_vm
relocate_enable_mmu
the satp write window
```

If Linux reaches a panic/restart breakpoint or the OpenSBI trap hang, the script
dumps CSRs plus early page-table memory. If it continues past the early
breakpoints without a trap, switch back to `test-08-linux-boot-smoke` and watch
UART for:

```text
CVA6 ZCU111 Linux initramfs reached
```
