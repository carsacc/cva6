# ZCU111 Linux Build Test

This test builds the first Linux artifacts for the validated CVA6 ZCU111 DDR4
platform. It starts from `allnoconfig` plus the local fragment so the generated
kernel stays small enough to load through JTAG during `test-08`.

Linux source stays outside this fork:

```sh
git clone --depth 1 --branch linux-6.6.y https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git /home/carlos/tools/linux
```

Install build dependencies:

```sh
sudo apt update
sudo apt install -y gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu \
  bc bison flex libssl-dev libelf-dev rsync cpio
```

Check the environment:

```sh
corev_apu/fpga/tests/test-07-linux-build/run.sh --check-only
```

Build:

```sh
corev_apu/fpga/tests/test-07-linux-build/run.sh
```

Expected artifacts:

```text
corev_apu/fpga/tests/test-07-linux-build/build/artifacts/Image
corev_apu/fpga/tests/test-07-linux-build/build/artifacts/vmlinux
corev_apu/fpga/tests/test-07-linux-build/build/artifacts/zcu111-linux.dtb
corev_apu/fpga/tests/test-07-linux-build/build/artifacts/initramfs.cpio
```

The initramfs contains a static `/init` program that prints:

```text
CVA6 ZCU111 Linux initramfs reached
```
