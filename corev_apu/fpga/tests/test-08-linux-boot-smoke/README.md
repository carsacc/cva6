# ZCU111 Linux Boot Smoke Test

This test loads OpenSBI `fw_jump.elf`, the Linux `Image`, and the ZCU111 Linux
DTB into DDR4 through GDB/OpenOCD. It then starts OpenSBI, waits for a short
boot window, and disconnects while the target keeps running.

Keep the UART terminal open on `/dev/ttyUSB2` at 115200 8N1 before launching
the test.

Prerequisites:

```sh
corev_apu/fpga/tests/run-openocd-zcu111.sh
corev_apu/fpga/tests/test-07-linux-build/run.sh
```

Run:

```sh
corev_apu/fpga/tests/test-08-linux-boot-smoke/run.sh
```

Load addresses:

```text
0x80000000  OpenSBI fw_jump
0x80200000  Linux Image
0x82200000  Linux DTB
```

Expected UART output includes the OpenSBI banner, Linux boot messages, and:

```text
CVA6 ZCU111 Linux initramfs reached
```
