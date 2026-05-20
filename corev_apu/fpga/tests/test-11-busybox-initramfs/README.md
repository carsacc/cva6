# ZCU111 BusyBox Initramfs Test

This test builds a static RISC-V BusyBox rootfs, embeds it as the Linux
initramfs, and boots it on the CVA6 ZCU111 DDR4/OpenSBI platform through
GDB/OpenOCD.

External source trees are kept outside this fork:

```sh
git clone --depth 1 --branch 1_36_1 https://git.busybox.net/busybox /home/carlos/tools/busybox
git clone --depth 1 --branch linux-6.6.y https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git /home/carlos/tools/linux
```

Run with OpenOCD active and UART open on `/dev/ttyUSB2` at 115200 8N1.
`picocom` is preferred over GUI serial loggers because it interprets BusyBox
ANSI color escapes correctly:

```sh
picocom -b 115200 /dev/ttyUSB2
```

In a second terminal, run:

```sh
corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh
```

Expected UART output includes:

```text
CVA6 ZCU111 BusyBox initramfs reached
~ #
```

Useful first commands:

```sh
uname -a
cat /proc/cpuinfo
dmesg | tail
ps
mount
```
