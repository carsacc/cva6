# ZCU111 Yocto Linux Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reproducible Yocto Linux path for the validated CVA6 ZCU111 platform.

**Architecture:** Start from the existing `meta-cva6-yocto` Honister layer and add a `cv64a6-zcu111` machine matching the already validated CVA6/ZCU111 memory map. The first boot path remains JTAG-loaded OpenSBI, kernel `Image`, DTB, and rootfs cpio to avoid adding SD/U-Boot variables before the OS image itself is proven.

**Tech Stack:** Yocto Honister, `meta-cva6-yocto`, `linux-yocto`, OpenSBI `fpga/cva6`, RISC-V 64-bit GCC, CVA6 ZCU111 PL DDR4, OpenOCD/GDB boot scripts.

---

## Baseline

- CVA6 repo branch: `zcu111-yocto-linux`, based on tag `zcu111-linux-reference-benchmarks`.
- Yocto layer repo branch: `zcu111-yocto-linux`, based on `meta-cva6-yocto` tag `meta-cva6-yocto-5.10`.
- Hardware assumptions:
  - CVA6 core clock: 50 MHz.
  - PL DDR4: `0x8000_0000..0xbfff_ffff`, 1 GiB.
  - UART: `0x1000_0000`, PLIC source 1, 115200 baud.
  - PL smoke peripheral: `0x5000_0000`, PLIC source 8, UIO.
  - AES-GCM MMIO peripheral: `0x5000_1000`, PLIC source 9, UIO.
- Ethernet on the ZCU111 RJ45 is PS GEM3 over MIO 64-77, not PL-accessible from this CVA6 design. Ethernet and Ethernet-to-AES pipeline stages are skipped for this feasibility path.

## Files

### CVA6 Repo

- Create: `docs/superpowers/plans/2026-06-02-zcu111-yocto-linux.md`
- Create: `corev_apu/fpga/tests/test-12-yocto-jtag-boot/README.md`
- Create: `corev_apu/fpga/tests/test-12-yocto-jtag-boot/gdb-yocto-boot.gdb`
- Create: `corev_apu/fpga/tests/test-12-yocto-jtag-boot/run.sh`

### Yocto Layer Repo

- Create: `conf/machine/cv64a6-zcu111.conf`
- Modify: `recipes-kernel/linux/linux-yocto_5.10.bbappend`
- Create: `recipes-kernel/linux/linux-yocto/cv64a6-zcu111/defconfig`
- Create: `recipes-kernel/linux/linux-yocto/cv64a6-zcu111.dts`
- Create: `recipes-images/cva6-zcu111/cva6-zcu111-image.bb`
- Create: `recipes-cva6/zcu111-tests/zcu111-tests.bb`
- Create: `recipes-cva6/zcu111-tests/files/mmio-test.c`
- Create: `recipes-cva6/zcu111-tests/files/irq-test.c`
- Create: `recipes-cva6/zcu111-tests/files/aes-gcm-test.c`
- Create: `scripts/check-zcu111-yocto-contract.sh`
- Modify: `README.md`

## Task 1: Add Yocto Contract Check

**Files:**
- Create: `riscv-cores/meta-cva6-yocto/scripts/check-zcu111-yocto-contract.sh`

- [ ] **Step 1: Create a static contract script**

The script must verify that the ZCU111 machine, kernel DTS, UIO support, and test recipes are present.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

test -f "${ROOT}/conf/machine/cv64a6-zcu111.conf"
test -f "${ROOT}/recipes-kernel/linux/linux-yocto/cv64a6-zcu111.dts"
test -f "${ROOT}/recipes-kernel/linux/linux-yocto/cv64a6-zcu111/defconfig"
test -f "${ROOT}/recipes-images/cva6-zcu111/cva6-zcu111-image.bb"
test -f "${ROOT}/recipes-cva6/zcu111-tests/zcu111-tests.bb"

grep -Fq 'MACHINEOVERRIDES =. "cv64a6-zcu111:"' "${ROOT}/conf/machine/cv64a6-zcu111.conf"
grep -Fq 'KERNEL_IMAGETYPE = "Image"' "${ROOT}/conf/machine/cv64a6-zcu111.conf"
grep -Fq 'IMAGE_FSTYPES += "cpio.gz ext4"' "${ROOT}/conf/machine/cv64a6-zcu111.conf"
grep -Fq 'RISCV_SBI_FDT ?= "cv64a6_zcu111.dtb"' "${ROOT}/conf/machine/cv64a6-zcu111.conf"

grep -Fq 'model = "CVA6 ZCU111 DDR4";' "${ROOT}/recipes-kernel/linux/linux-yocto/cv64a6-zcu111.dts"
grep -Fq 'memory@80000000' "${ROOT}/recipes-kernel/linux/linux-yocto/cv64a6-zcu111.dts"
grep -Fq 'serial@10000000' "${ROOT}/recipes-kernel/linux/linux-yocto/cv64a6-zcu111.dts"
grep -Fq 'pl-peripheral@50000000' "${ROOT}/recipes-kernel/linux/linux-yocto/cv64a6-zcu111.dts"
grep -Fq 'aes-gcm@50001000' "${ROOT}/recipes-kernel/linux/linux-yocto/cv64a6-zcu111.dts"

grep -Fq 'CONFIG_UIO=y' "${ROOT}/recipes-kernel/linux/linux-yocto/cv64a6-zcu111/defconfig"
grep -Fq 'CONFIG_UIO_PDRV_GENIRQ=y' "${ROOT}/recipes-kernel/linux/linux-yocto/cv64a6-zcu111/defconfig"
grep -Fq 'CONFIG_SERIAL_8250_CONSOLE=y' "${ROOT}/recipes-kernel/linux/linux-yocto/cv64a6-zcu111/defconfig"

echo "PASS: ZCU111 Yocto contract present"
```

- [ ] **Step 2: Run it and confirm it fails before implementation**

Run:

```bash
cd /home/carlos/projects/CHAOS/riscv-cores/meta-cva6-yocto
scripts/check-zcu111-yocto-contract.sh
```

Expected: fails because the ZCU111 machine files do not exist yet.

## Task 2: Add `cv64a6-zcu111` Machine And Kernel Inputs

**Files:**
- Create: `conf/machine/cv64a6-zcu111.conf`
- Modify: `recipes-kernel/linux/linux-yocto_5.10.bbappend`
- Create: `recipes-kernel/linux/linux-yocto/cv64a6-zcu111.dts`
- Create: `recipes-kernel/linux/linux-yocto/cv64a6-zcu111/defconfig`

- [ ] **Step 1: Create machine config**

The machine config must avoid U-Boot/SD in the first phase and produce raw `Image`, DTB, rootfs cpio, and ext4 artifacts.

```bitbake
#@TYPE: Machine
#@NAME: cv64a6-zcu111
#@SOC: cv64a6 zcu111
#@DESCRIPTION: Machine configuration for CV64A6 on the AMD ZCU111 PL DDR4 platform

require conf/machine/include/riscv/tune-riscv.inc

MACHINE_FEATURES = "ext2 ext3 serial"
MACHINEOVERRIDES =. "cv64a6-zcu111:"

KERNEL_IMAGETYPE = "Image"
PREFERRED_PROVIDER_virtual/kernel ?= "linux-yocto"
PREFERRED_VERSION_linux-yocto = "5.10.7%"

EXTRA_IMAGEDEPENDS += "opensbi"

RISCV_SBI_PLAT = "fpga/cva6"
RISCV_SBI_PAYLOAD ?= ""
RISCV_SBI_FDT ?= "cv64a6_zcu111.dtb"
KERNEL_DEVICETREE ?= "openhwgroup/${RISCV_SBI_FDT}"

SERIAL_CONSOLES = "115200;ttyS0"

IMAGE_FSTYPES += "cpio.gz ext4"
IMAGE_BOOT_FILES ?= "fw_jump.bin ${KERNEL_IMAGETYPE} ${RISCV_SBI_FDT}"

UBOOT_ENTRYPOINT = "0x80200000"
UBOOT_DTB_LOADADDRESS = "0x82200000"
```

- [ ] **Step 2: Add Linux recipe machine override**

Append ZCU111 files in `recipes-kernel/linux/linux-yocto_5.10.bbappend`:

```bitbake
SRC_URI:append:cv64a6-zcu111 = " file://cv64a6-zcu111.dts \
                                  file://cv64a6-zcu111/defconfig \
                                "

COMPATIBLE_MACHINE:append:cv64a6-zcu111 = "|cv64a6-zcu111"

do_configure:append:cv64a6-zcu111() {
    install -d ${S}/arch/riscv/boot/dts/openhwgroup
    install -m 0644 ${WORKDIR}/cv64a6-zcu111.dts ${S}/arch/riscv/boot/dts/openhwgroup/cv64a6_zcu111.dts
    grep -Fq 'cv64a6_zcu111.dtb' ${S}/arch/riscv/boot/dts/openhwgroup/Makefile || \
        echo 'dtb-$(CONFIG_SOC_CVA6) += cv64a6_zcu111.dtb' >> ${S}/arch/riscv/boot/dts/openhwgroup/Makefile
}
```

- [ ] **Step 3: Add ZCU111 DTS**

Use the validated ZCU111 DTS from the CVA6 tests. It must include CPU, memory, CLINT, PLIC, UART, PL peripheral UIO, and AES-GCM UIO.

- [ ] **Step 4: Add ZCU111 defconfig**

Start from the validated Linux config and keep at least:

```text
CONFIG_64BIT=y
CONFIG_RISCV=y
CONFIG_RISCV_SBI=y
CONFIG_MMU=y
CONFIG_FPU=y
CONFIG_CMDLINE="console=ttyS0,115200 earlycon=sbi root=/dev/ram rdinit=/sbin/init loglevel=8 uio_pdrv_genirq.of_id=generic-uio"
CONFIG_CMDLINE_FORCE=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_SERIAL_EARLYCON=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_OF_PLATFORM=y
CONFIG_RISCV_TIMER=y
CONFIG_RISCV_INTC=y
CONFIG_SIFIVE_PLIC=y
CONFIG_UIO=y
CONFIG_UIO_PDRV_GENIRQ=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_TMPFS=y
```

- [ ] **Step 5: Run static contract**

Run:

```bash
cd /home/carlos/projects/CHAOS/riscv-cores/meta-cva6-yocto
scripts/check-zcu111-yocto-contract.sh
```

Expected: `PASS: ZCU111 Yocto contract present`.

## Task 3: Add ZCU111 Image And Userland Tests

**Files:**
- Create: `recipes-images/cva6-zcu111/cva6-zcu111-image.bb`
- Create: `recipes-cva6/zcu111-tests/zcu111-tests.bb`
- Create: `recipes-cva6/zcu111-tests/files/mmio-test.c`
- Create: `recipes-cva6/zcu111-tests/files/irq-test.c`
- Create: `recipes-cva6/zcu111-tests/files/aes-gcm-test.c`

- [ ] **Step 1: Add image recipe**

```bitbake
SUMMARY = "CVA6 ZCU111 validation image"
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "debug-tweaks"

IMAGE_INSTALL:append = " \
    busybox \
    zcu111-tests \
"
```

- [ ] **Step 2: Add test recipe**

```bitbake
SUMMARY = "CVA6 ZCU111 platform validation utilities"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://mmio-test.c \
    file://irq-test.c \
    file://aes-gcm-test.c \
"

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -O2 -Wall -Wextra -o mmio-test mmio-test.c
    ${CC} ${CFLAGS} ${LDFLAGS} -O2 -Wall -Wextra -o irq-test irq-test.c
    ${CC} ${CFLAGS} ${LDFLAGS} -O2 -Wall -Wextra -o aes-gcm-test aes-gcm-test.c
}

do_install() {
    install -d ${D}/root
    install -m 0755 mmio-test ${D}/root/mmio-test
    install -m 0755 irq-test ${D}/root/irq-test
    install -m 0755 aes-gcm-test ${D}/root/aes-gcm-test
}

FILES:${PN} += "/root/mmio-test /root/irq-test /root/aes-gcm-test"
```

- [ ] **Step 3: Copy validated test sources**

Copy the C sources from:

```text
/home/carlos/projects/CHAOS/riscv-cores/cva6/corev_apu/fpga/tests/test-11-busybox-initramfs/mmio-test/mmio-test.c
/home/carlos/projects/CHAOS/riscv-cores/cva6/corev_apu/fpga/tests/test-11-busybox-initramfs/irq-test/irq-test.c
/home/carlos/projects/CHAOS/riscv-cores/cva6/corev_apu/fpga/tests/test-11-busybox-initramfs/aes-gcm-test/aes-gcm-test.c
```

## Task 4: Add JTAG Boot Smoke Test

**Files:**
- Create: `corev_apu/fpga/tests/test-12-yocto-jtag-boot/README.md`
- Create: `corev_apu/fpga/tests/test-12-yocto-jtag-boot/gdb-yocto-boot.gdb`
- Create: `corev_apu/fpga/tests/test-12-yocto-jtag-boot/run.sh`

- [ ] **Step 1: Add GDB loader**

The loader must load:

```text
OpenSBI fw_jump.elf at 0x80000000
Yocto Image at 0x80200000
Yocto rootfs cpio.gz at 0x84000000
Yocto DTB at 0x82200000
```

The DTB must include `linux,initrd-start` and `linux,initrd-end` in `/chosen`.

- [ ] **Step 2: Add run script**

The script must locate Yocto deploy artifacts under:

```text
/home/carlos/projects/CHAOS/riscv-cores/cva6-yocto/build/tmp-glibc/deploy/images/cv64a6-zcu111
```

It must print the expected UART line:

```text
Poky (Yocto Project Reference Distro)
```

and then detach while Linux keeps running.

## Task 5: Build And Hardware Validation

- [ ] **Step 1: Build Yocto image**

Run from the Yocto workspace:

```bash
MACHINE=cv64a6-zcu111 bitbake cva6-zcu111-image
```

Expected artifacts:

```text
Image
cv64a6_zcu111.dtb
cva6-zcu111-image-cv64a6-zcu111.rootfs.cpio.gz
fw_jump.elf
```

- [ ] **Step 2: Boot through JTAG**

Run:

```bash
corev_apu/fpga/tests/test-12-yocto-jtag-boot/run.sh
```

Expected UART evidence:

```text
OpenSBI
Linux version
Poky (Yocto Project Reference Distro)
```

- [ ] **Step 3: Validate userland**

Run in the Yocto shell:

```sh
/root/mmio-test
/root/irq-test
/root/aes-gcm-test
```

Expected:

```text
PASS: PL peripheral MMIO test completed
PASS: PL peripheral IRQ test completed
PASS: AES-256-GCM MMIO/IRQ known-answer tests completed
```

## Task 6: Commit And Tag

- [ ] **Step 1: Commit Yocto layer changes**

```bash
cd /home/carlos/projects/CHAOS/riscv-cores/meta-cva6-yocto
git add conf/machine/cv64a6-zcu111.conf recipes-kernel/linux/linux-yocto_5.10.bbappend recipes-kernel/linux/linux-yocto/cv64a6-zcu111.dts recipes-kernel/linux/linux-yocto/cv64a6-zcu111/defconfig recipes-images/cva6-zcu111/cva6-zcu111-image.bb recipes-cva6/zcu111-tests scripts/check-zcu111-yocto-contract.sh README.md
git commit -m "feat: add cv64a6 zcu111 yocto machine"
```

- [ ] **Step 2: Commit CVA6 boot test changes**

```bash
cd /home/carlos/projects/CHAOS/riscv-cores/cva6
git add docs/superpowers/plans/2026-06-02-zcu111-yocto-linux.md corev_apu/fpga/tests/test-12-yocto-jtag-boot
git commit -m "test(fpga): add zcu111 yocto jtag boot smoke"
```

- [ ] **Step 3: Tag after physical validation**

Only after the Yocto image boots on the ZCU111 and the three userland tests pass:

```bash
git tag -a zcu111-yocto-jtag-linux -m "ZCU111 CVA6 Yocto Linux boots through JTAG and validates PL peripherals"
```

## Self-Review

- Spec coverage: The plan covers Yocto machine metadata, kernel DT/config, image recipe, validation utilities, JTAG boot, physical validation, and milestone tagging.
- Placeholder scan: No implementation step uses TBD/TODO or unspecified file paths.
- Type consistency: The machine name is consistently `cv64a6-zcu111`; the DTB is consistently `cv64a6_zcu111.dtb`; the branch name is `zcu111-yocto-linux`.
