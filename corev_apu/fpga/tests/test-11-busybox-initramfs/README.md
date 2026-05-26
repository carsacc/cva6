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
It tracks the BusyBox/Linux source revisions, local scripts/configs, the
vendored customer benchmark snapshot, and toolchain version. Use `--build-only` to
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
./run-reference-benchmarks
./memstress 256M
./mmio-test
./irq-test
```

The CPU benchmarks are included for manual execution only. The `/init` script
does not run them automatically. They are compiled from the exact source
snapshot used by the customer reference measurements under
`reference-benchmarks/`, and are fixed to single-context execution because this
CVA6 system contains one HART. The generic upstream CoreMark README mentions
parallel modes; those modes are not part of the ZCU111 comparison protocol.

Run the complete reference protocol with:

```sh
cd /root
./run-reference-benchmarks
```

It executes raw CoreMark using the same customer arguments:

```sh
./coremark 0x0 0x0 0x66 0 7 1 2000
```

Expected validated CoreMark lines:

```text
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
Correct operation validated. See README.md for run and reporting rules.
```

`crcfinal` is iteration-dependent. Because the customer protocol uses
`ITERATIONS=0`, each platform automatically selects a sufficient run length:
the customer log reported `0xa14c` at `600000` iterations, while the physical
CVA6 validation reported `0x33ff` at `1100` iterations.

It then executes Dhrystone 2.1 beginning at `20000000` runs and repeats with
twice the run count only if the original program reports that the measured time
is too small. The wrapper derives `CoreMark/MHz` and `DMIPS/MHz` using the fixed
50 MHz CVA6 core clock; the raw benchmark outputs remain the primary comparable
results. Dhrystone can take several minutes at this clock rate.

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
