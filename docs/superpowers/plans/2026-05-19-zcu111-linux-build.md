# ZCU111 Linux Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reproducible test stage that builds minimal Linux boot artifacts for the validated CVA6 ZCU111 DDR4/OpenSBI platform.

**Architecture:** Keep Linux source outside the CVA6 fork under `/home/carlos/tools/linux`. Store only board-specific scripts, config fragments, initramfs source, and documentation in this repo. Build a RISC-V `Image`, a Linux DTB from the current ZCU111 device tree, and an initramfs containing a tiny static `/init` program.

**Tech Stack:** Linux `linux-6.6.y`, `riscv64-linux-gnu-gcc`, OpenSBI-compatible RISC-V supervisor boot, DTB, initramfs CPIO, UART 8250 console.

---

## File Structure

- Create: `corev_apu/fpga/tests/test-07-linux-build/run.sh`
  - Validate dependencies, locate Linux source, build initramfs, merge kernel config, build `Image`, and stage artifacts.
- Create: `corev_apu/fpga/tests/test-07-linux-build/init.c`
  - Tiny static PID 1 program that prints a visible boot marker, reads `/proc/cpuinfo` when available, and loops.
- Create: `corev_apu/fpga/tests/test-07-linux-build/zcu111-linux.dts`
  - Linux device tree matching current DDR4, CLINT, PLIC, and UART.
- Create: `corev_apu/fpga/tests/test-07-linux-build/linux-zcu111.fragment`
  - Kernel config fragment for serial console, initramfs, RISC-V SBI, CLINT timer, PLIC, and early printk support.
- Create: `corev_apu/fpga/tests/test-07-linux-build/README.md`
  - Usage, external source setup, dependency install command, and artifact paths.
- Modify: `corev_apu/fpga/tests/README.md`
  - Add `test-07-linux-build` to the staged sequence.

## Task 1: Add Linux Build Test Sources

**Files:**
- Create all files under `corev_apu/fpga/tests/test-07-linux-build/`.

- [ ] **Step 1: Add `init.c`**

The init program must be freestanding enough for initramfs use, use direct syscalls/libc calls only, print `CVA6 ZCU111 Linux initramfs reached`, then loop with a heartbeat.

- [ ] **Step 2: Add Linux DTS**

The DTS must describe:

- `memory@80000000`, 1 GiB.
- CPU `rv64imafdc`, `mmu-type = "riscv,sv39"`.
- CLINT at `0x02000000`.
- PLIC at `0x0c000000`.
- UART 8250 at `0x10000000`, `clock-frequency = <50000000>`, `reg-shift = <2>`.
- `chosen.bootargs = "console=ttyS0,115200 earlycon=sbi root=/dev/ram rdinit=/init loglevel=8"`.

- [ ] **Step 3: Add config fragment**

The fragment must enable initramfs source path support, serial 8250 console, RISC-V SBI, PLIC, CLINT timer, procfs, tmpfs, and panic/reboot-friendly debug settings.

- [ ] **Step 4: Add `run.sh`**

The script must:

1. Check `riscv64-linux-gnu-gcc`, `dtc`, `make`, and Linux source.
2. Compile `init.c` statically with `riscv64-linux-gnu-gcc`.
3. Create `build/initramfs.cpio` with `/init`.
4. Copy `zcu111-linux.dts` into the Linux build tree and build `zcu111-linux.dtb`.
5. Run `make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- defconfig`.
6. Merge `linux-zcu111.fragment` using Linux `scripts/kconfig/merge_config.sh`.
7. Build `arch/riscv/boot/Image`.
8. Copy `Image`, `vmlinux`, `zcu111-linux.dtb`, and `initramfs.cpio` into `build/artifacts/`.

## Task 2: Document Usage

**Files:**
- Create: `corev_apu/fpga/tests/test-07-linux-build/README.md`
- Modify: `corev_apu/fpga/tests/README.md`

- [ ] **Step 1: Document dependencies**

Document:

```bash
sudo apt update
sudo apt install -y gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu \
  bc bison flex libssl-dev libelf-dev rsync cpio
```

- [ ] **Step 2: Document Linux source setup**

Document:

```bash
git clone --depth 1 --branch linux-6.6.y https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git /home/carlos/tools/linux
```

- [ ] **Step 3: Document artifacts**

Document that successful builds create:

```text
corev_apu/fpga/tests/test-07-linux-build/build/artifacts/Image
corev_apu/fpga/tests/test-07-linux-build/build/artifacts/vmlinux
corev_apu/fpga/tests/test-07-linux-build/build/artifacts/zcu111-linux.dtb
corev_apu/fpga/tests/test-07-linux-build/build/artifacts/initramfs.cpio
```

## Task 3: Verify

**Files:**
- All files touched by this plan.

- [ ] **Step 1: Run dependency check**

Run:

```bash
corev_apu/fpga/tests/test-07-linux-build/run.sh --check-only
```

Expected: either prints all dependencies found, or exits with actionable install/clone commands.

- [ ] **Step 2: Run build if dependencies are present**

Run:

```bash
corev_apu/fpga/tests/test-07-linux-build/run.sh
```

Expected: creates all four artifacts listed above.

- [ ] **Step 3: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: no output.
