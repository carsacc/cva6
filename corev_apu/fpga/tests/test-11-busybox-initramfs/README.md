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

The script rebuilds only when its inputs changed or when artifacts are missing.
It tracks the BusyBox/Linux source revisions, local scripts/configs, CoreMark
sources, toolchain version, and `COREMARK_*` settings. Use `--build-only` to
prepare artifacts without launching GDB/OpenOCD:

```sh
corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh --build-only
```

Force a clean refresh of the generated artifacts with:

```sh
corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh --rebuild --build-only
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
cd /root
./coremark
./memstress 256M
./mmio-test
./irq-test
```

The CoreMark binary is included for manual execution only. The `/init` script
does not run it automatically. The Linux port reads the RISC-V `cycle` counter
and uses the current 50 MHz CVA6 clock to report `CoreMark/MHz`. Override the
build-time run length or clock assumption with:

```sh
COREMARK_ITERATIONS=2000 corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh
COREMARK_CLOCK_HZ=50000000 corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh
```

The `memstress` binary is also included for manual Linux DDR4 stress testing.
It allocates anonymous Linux memory and checks address-dependent patterns from
userland, so it exercises DDR4 through the kernel, MMU, caches, and normal
userspace mappings. Sizes use binary suffixes:

```sh
cd /root
./memstress 256M
./memstress 512M
./memstress 768M
```

Expected completion line:

```text
PASS: DDR4 memstress completed
```

The `mmio-test` binary validates the first functional PL peripheral window at
`0x50000000`. It reads the ID/version registers, writes and verifies the scratch
register, and checks that the free-running counter advances.

Expected completion line:

```text
PASS: PL peripheral MMIO test completed
```

The `irq-test` binary validates the same PL peripheral interrupt path through
Linux UIO. It opens `/dev/uio0`, maps the PL peripheral registers, triggers two
interrupts, acks the device-side status bit, and re-enables the UIO interrupt
line between rounds.

Expected completion line:

```text
PASS: PL peripheral IRQ test completed
```
