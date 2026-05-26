# ZCU111 Reference CPU Benchmarks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the non-comparable ZCU111 CoreMark build with the customer's reference snapshot and add matching Dhrystone/normalised reporting inside the Linux initramfs.

**Architecture:** Vendor the exact benchmark source snapshot from `cpu_benchmark` under `test-11-busybox-initramfs/reference-benchmarks`, validate its SHA-256 provenance before builds, and compile raw static Linux executables into `/root`. A shell runner executes the customer's protocols and calculates normalised values externally at the fixed 50 MHz CVA6 clock, without altering the timed workload sources.

**Tech Stack:** Bash, BusyBox initramfs, RISC-V Linux static binaries, EEMBC CoreMark POSIX port, Dhrystone 2.1, `riscv64-linux-gnu-gcc`.

---

### Task 1: Pin The Reference Snapshot

**Files:**
- Create: `corev_apu/fpga/tests/test-11-busybox-initramfs/check-reference-benchmark-sources.sh`
- Create: `corev_apu/fpga/tests/test-11-busybox-initramfs/reference-benchmarks/ORIGIN.sha256`
- Create: `corev_apu/fpga/tests/test-11-busybox-initramfs/reference-benchmarks/coremark/*`
- Create: `corev_apu/fpga/tests/test-11-busybox-initramfs/reference-benchmarks/dhrystone/*`

- [ ] **Step 1: Write the failing source provenance check**

Create a script which invokes `sha256sum -c` from
`reference-benchmarks/ORIGIN.sha256` and fails until the baseline source tree
is present.

- [ ] **Step 2: Run it to verify RED**

Run:

```bash
corev_apu/fpga/tests/test-11-busybox-initramfs/check-reference-benchmark-sources.sh
```

Expected: failure because `reference-benchmarks/ORIGIN.sha256` or its files do
not yet exist.

- [ ] **Step 3: Vendor the exact customer snapshot**

Copy the required CoreMark files, POSIX port, Dhrystone files, and licensing
metadata from `/home/carlos/projects/CHAOS/cpu_benchmark/third_party/` without
source changes. Add `ORIGIN.sha256` containing the approved hashes from the
design spec.

- [ ] **Step 4: Run it to verify GREEN**

Run the same provenance checker. Expected: `PASS: reference benchmark snapshot matches customer baseline`.

### Task 2: Make Initramfs Demand Comparable Binaries

**Files:**
- Modify: `corev_apu/fpga/tests/test-11-busybox-initramfs/check-rootfs.sh`

- [ ] **Step 1: Extend the rootfs check before adding builds**

Require static RISC-V executables at `/root/coremark` and `/root/dhrystone`,
an executable `/root/run-reference-benchmarks`, and verify that the script
contains the raw CoreMark command:

```sh
/root/coremark 0x0 0x0 0x66 0 7 1 2000
```

- [ ] **Step 2: Run it to verify RED**

Run:

```bash
corev_apu/fpga/tests/test-11-busybox-initramfs/check-rootfs.sh
```

Expected: failure because `/root/dhrystone` and
`/root/run-reference-benchmarks` do not yet exist.

### Task 3: Build The Raw Reference Executables And Runner

**Files:**
- Create: `corev_apu/fpga/tests/test-11-busybox-initramfs/run-reference-benchmarks`
- Modify: `corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh`

- [ ] **Step 1: Replace the CoreMark build input**

Compile baseline `core_main.c`, algorithm sources and `posix/core_portme.c`
with:

```bash
riscv64-linux-gnu-gcc -static -O3 -march=rv64gc -mabi=lp64d \
  -DPERFORMANCE_RUN=1 -DITERATIONS=0 \
  -DFLAGS_STR="\"-static -O3 -march=rv64gc -mabi=lp64d -DPERFORMANCE_RUN=1 -DITERATIONS=0 -lrt\"" \
  -I reference-benchmarks/coremark -I reference-benchmarks/coremark/posix \
  -o coremark core_list_join.c core_main.c core_matrix.c core_state.c \
  core_util.c posix/core_portme.c -lrt
```

- [ ] **Step 2: Add Dhrystone build**

Copy `dhry_1.c`, `dhry_2.c`, and `dhry.h` into the generated build directory,
apply only the same two compatibility deletions made by the customer runner,
and compile a static RISC-V `/root/dhrystone` using `-std=gnu89 -O3
-march=rv64gc -mabi=lp64d -DHZ=100 -include string.h -include stdlib.h`.

- [ ] **Step 3: Add the external report runner**

Install `/root/run-reference-benchmarks`. It runs CoreMark with the fixed
customer arguments, parses raw `CoreMark 1.0`, runs Dhrystone starting at
`20,000,000` runs and doubling only on its standard short-time message, then
prints:

```text
CoreMark/MHz: <coremark / 50>
DMIPS: <dhrystones/sec / 1757>
DMIPS/MHz: <dmips / 50>
```

- [ ] **Step 4: Make rebuild signatures include every new input**

Hash `ORIGIN.sha256`, every vendored workload source, the report runner and
the provenance checker in `build_inputs()`, and call the provenance checker
before building.

- [ ] **Step 5: Run rootfs verification GREEN**

Run:

```bash
corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh --build-only
```

Expected: rootfs check reports static RISC-V CoreMark and Dhrystone plus the
installed runner and ends with `Build-only mode complete.`

### Task 4: Document And Physically Validate

**Files:**
- Modify: `corev_apu/fpga/tests/test-11-busybox-initramfs/README.md`

- [ ] **Step 1: Update operating instructions**

Document the replaced reference-compatible `/root/coremark`, new
`/root/dhrystone`, `/root/run-reference-benchmarks`, expected CRC `0xa14c`,
normalisation at 50 MHz, and that Dhrystone may take minutes on CVA6.

- [ ] **Step 2: Boot the current hardware with rebuilt Linux image**

Run:

```bash
corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh
```

Expected: Linux reaches the BusyBox prompt; no new bitstream is required.

- [ ] **Step 3: Run raw and reported benchmarks on ZCU111**

Run on UART:

```sh
cd /root
./coremark 0x0 0x0 0x66 0 7 1 2000
printf '20000000\n' | ./dhrystone
./run-reference-benchmarks
```

Expected: CoreMark reports standard CRCs including `crcfinal: 0xa14c`;
Dhrystone reports `Dhrystones per Second`; wrapper reports `CoreMark/MHz`,
`DMIPS`, and `DMIPS/MHz`.

- [ ] **Step 4: Commit and tag only after physical validation**

After UART evidence is captured:

```bash
git add corev_apu/fpga/tests/test-11-busybox-initramfs docs/superpowers
git commit -m "test(fpga): align zcu111 linux CPU benchmarks with reference"
git tag -a zcu111-linux-reference-benchmarks -m "ZCU111 reference-compatible CPU benchmarks validated"
```
