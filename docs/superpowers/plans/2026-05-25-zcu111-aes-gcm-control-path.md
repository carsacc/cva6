# ZCU111 AES-GCM Control Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an AES-256-GCM PL peripheral that Linux can drive through MMIO and complete through a dedicated UIO interrupt, validated with known-answer vectors.

**Architecture:** Keep the validated diagnostic peripheral at `0x50000000` and PLIC source `8`. Add a separate `AESGCM` crossbar target at `0x50001000` and PLIC source `9`, wrapping an attributable BLu85 AES-GCM VHDL core configured for AES-256, medium area, no extra round pipelining. Stage 1 accepts at most one 128-bit AAD block and one 128-bit payload block through registers; the later DDR4 data-path milestone will keep this control contract and replace register payload movement with AXI buffer descriptors.

**Tech Stack:** SystemVerilog AXI wrapper and SoC integration, BLu85 VHDL AES-GCM IP, Vivado 2022.2 on Windows, Linux device tree, static RISC-V BusyBox userland test.

---

## Stage-1 Register Contract

All registers are 32-bit little-endian MMIO words in the AES-GCM window at
`0x50001000`. Cryptographic vectors use network order: `KEY0`, `IV0`, `AAD0`
and `DATA_IN0` contain the most significant 32 bits of their vectors.

| Offset | Name | Access | Meaning |
| ---: | --- | --- | --- |
| `0x00` | `ID` | R | `0x4147434d` (`AGCM`) |
| `0x04` | `VERSION` | R | `0x00010000` |
| `0x08` | `CONTROL` | W | bit 0 `START`, bit 1 `DECRYPT`, bit 2 `CLEAR` |
| `0x0c` | `STATUS` | R | bit 0 `BUSY`, bit 1 `DONE`, bit 2 `TAG_VALID`, bit 3 `ICB_OVERFLOW` |
| `0x10` | `IRQ_ENABLE` | R/W | bit 0 completion enable |
| `0x14` | `IRQ_STATUS` | R | bit 0 pending |
| `0x18` | `IRQ_ACK` | W | write bit 0 to clear completion |
| `0x20..0x3c` | `KEY0..KEY7` | R/W | AES-256 key |
| `0x40..0x48` | `IV0..IV2` | R/W | 96-bit IV |
| `0x4c` | `AAD_BYTES` | R/W | `0..16` |
| `0x50..0x5c` | `AAD0..AAD3` | R/W | one AAD block |
| `0x60` | `DATA_BYTES` | R/W | `0..16` |
| `0x64..0x70` | `DATA_IN0..DATA_IN3` | R/W | one plaintext/ciphertext block |
| `0x74..0x80` | `DATA_OUT0..DATA_OUT3` | R | output block |
| `0x84..0x90` | `TAG0..TAG3` | R | generated authentication tag |

`DECRYPT` computes plaintext and a tag; stage-1 software compares the tag with
the expected KAT tag and treats mismatch as authentication failure.

### Task 1: Preserve Design And Third-Party Provenance

**Files:**
- Modify: `docs/superpowers/specs/2026-05-25-zcu111-aes-gcm-roadmap.md`
- Create: `corev_apu/fpga/src/third_party/blu85_aes_gcm/ORIGIN.md`
- Create: `corev_apu/fpga/src/third_party/blu85_aes_gcm/src/*.vhd`

- [ ] **Step 1: Record the integration decision**

Ensure the roadmap states that `pl-peripheral` remains on PLIC `8` and
AES-GCM receives PLIC `9`, avoiding shared UIO ownership.

- [ ] **Step 2: Import an attributable source snapshot**

Fetch upstream commit `7f6f43a971362ccaf4bb5416bc7ff96a63119005`, generate
the AES-256 medium/no-pipeline configuration with:

```sh
python3 config/gcm_config.py --mode 256 --size M --pipe 0
```

Copy the VHDL implementation and generated `src/gen_rtl/*.vhd` into the
third-party source directory. `ORIGIN.md` must record URL, commit, invocation,
the README Apache-2.0 statement, and that no standalone `LICENSE` file was
present in that snapshot.

- [ ] **Step 3: Commit the documentation and imported IP**

```sh
git add docs/superpowers/specs/2026-05-25-zcu111-aes-gcm-roadmap.md \
  docs/superpowers/plans/2026-05-25-zcu111-aes-gcm-control-path.md \
  corev_apu/fpga/src/third_party/blu85_aes_gcm
git commit -m "docs(fpga): define zcu111 aes-gcm control-path milestone"
```

### Task 2: Add Failing Software Contract Checks

**Files:**
- Create: `corev_apu/fpga/tests/test-11-busybox-initramfs/aes-gcm-test/aes-gcm-test.c`
- Modify: `corev_apu/fpga/tests/test-11-busybox-initramfs/check-rootfs.sh`
- Modify: `corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh`

- [ ] **Step 1: Extend the rootfs check before adding its build**

Add the expected executable:

```sh
AES_GCM_TEST="${ROOTFS_DIR}/root/aes-gcm-test"
check_static_riscv_binary "${AES_GCM_TEST}" "AES-GCM KAT test"
```

- [ ] **Step 2: Run the check to observe RED**

Run:

```sh
ROOTFS_DIR=corev_apu/fpga/tests/test-11-busybox-initramfs/build/rootfs \
  corev_apu/fpga/tests/test-11-busybox-initramfs/check-rootfs.sh
```

Expected: failure reporting missing executable
`/root/aes-gcm-test`.

- [ ] **Step 3: Add the KAT utility**

Implement a UIO test executable that maps the AES-GCM UIO device, writes the
register contract above, enables IRQ, waits for completion, and compares
`DATA_OUT` and `TAG` for AES-256-GCM vectors. It must execute:

```c
static const struct kat cases[] = {
  {
    .name = "empty plaintext and aad",
    .key = {0}, .iv = {0},
    .aad_bytes = 0, .data_bytes = 0,
    .tag = {0x53,0x0f,0x8a,0xfb,0xc7,0x45,0x36,0xb9,
            0xa9,0x63,0xb4,0xf1,0xc4,0xcb,0x73,0x8b}
  },
  {
    .name = "single plaintext block",
    .key = {0}, .iv = {0},
    .plaintext = {0}, .data_bytes = 16,
    .ciphertext = {0xce,0xa7,0x40,0x3d,0x4d,0x60,0x6b,0x6e,
                   0x07,0x4e,0xc5,0xd3,0xba,0xf3,0x9d,0x18},
    .tag = {0xd0,0xd1,0xc8,0xa7,0x99,0x99,0x6b,0xf0,
            0x26,0x5b,0x98,0xb5,0xd4,0x8a,0xb9,0x19}
  }
};
```

The executable must run the data-block case in both encryption and decryption
directions and print:

```text
PASS: AES-256-GCM MMIO/IRQ known-answer tests completed
```

- [ ] **Step 4: Build and install the utility**

Add `build_aes_gcm_test()` in `run.sh`, include its C source in
`build_inputs()`, install it as `/root/aes-gcm-test`, and call it after
`build_irq_test`.

- [ ] **Step 5: Run the rootfs build check to observe GREEN**

Run:

```sh
corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh --build-only
```

Expected: `PASS: rootfs contains static RISC-V AES-GCM KAT test`.

### Task 3: Add AES-GCM SoC Address And Interrupt Contract

**Files:**
- Modify: `corev_apu/tb/ariane_soc_pkg.sv`
- Modify: `corev_apu/fpga/src/ariane_xilinx.sv`
- Modify: `corev_apu/fpga/src/ariane_peripherals_xilinx.sv`
- Modify: `corev_apu/fpga/tests/test-05-opensbi-smoke/zcu111-cva6.dts`
- Modify: `corev_apu/fpga/tests/test-07-linux-build/zcu111-linux.dts`

- [ ] **Step 1: Add a failing static contract check**

Run before modifying the map:

```sh
rg -n "AESGCM|aes-gcm@50001000|aes_irq_i|irq_sources\\[8\\]" \
  corev_apu/tb/ariane_soc_pkg.sv \
  corev_apu/fpga/src/ariane_xilinx.sv \
  corev_apu/fpga/src/ariane_peripherals_xilinx.sv \
  corev_apu/fpga/tests/test-05-opensbi-smoke/zcu111-cva6.dts \
  corev_apu/fpga/tests/test-07-linux-build/zcu111-linux.dts
```

Expected: no AES-GCM address/IRQ matches.

- [ ] **Step 2: Add the crossbar window**

Extend `ariane_soc` with:

```systemverilog
AESGCM = 11,
localparam NB_PERIPHERALS = AESGCM + 1;
localparam logic [63:0] AESGCMLength = 64'h1000;
AESGCMBase = 64'h5000_1000,
```

and add its `addr_map` rule to `ariane_xilinx.sv`.

- [ ] **Step 3: Allocate a dedicated PLIC input**

Extend `ariane_peripherals` with `input logic aes_irq_i`, preserving:

```systemverilog
assign irq_sources[7] = pl_irq_i;
assign irq_sources[8] = aes_irq_i;
```

Declare/connect `aes_irq` in `ariane_xilinx.sv`.

- [ ] **Step 4: Advertise the Linux UIO node**

Add to both DTS files:

```dts
aes_gcm0: aes-gcm@50001000 {
    compatible = "generic-uio", "tst,zcu111-aes-gcm";
    reg = <0x0 0x50001000 0x0 0x1000>;
    interrupts = <9>;
    interrupt-parent = <&plic0>;
};
```

The test utility selects the UIO instance by reading sysfs `name`; it must not
assume that adding this node leaves AES at `/dev/uio0`.

### Task 4: Implement The AXI Register Wrapper And AES Sequencer

**Files:**
- Create: `corev_apu/fpga/src/zcu111_aes_gcm_peripheral.sv`
- Modify: `corev_apu/fpga/src/ariane_xilinx.sv`
- Modify: `corev_apu/fpga/scripts/run.tcl`

- [ ] **Step 1: Add compile contract check before RTL exists**

Run:

```sh
test -f corev_apu/fpga/src/zcu111_aes_gcm_peripheral.sv
```

Expected: failure because the wrapper is absent.

- [ ] **Step 2: Write the independent AXI slave wrapper**

Implement an AXI slave following `zcu111_pl_peripheral.sv` response handling,
using the register contract in this plan. Its FSM must perform:

```systemverilog
IDLE -> CORE_RESET -> LOAD_KEY -> LOAD_IV -> START_COUNTER ->
WAIT_READY -> FEED_AAD/FEED_DATA -> CLOSE_PACKET -> WAIT_TAG -> DONE
```

`DONE` captures output/tag, asserts `irq_status_q`, and remains observable
until software writes `IRQ_ACK` or `CONTROL.CLEAR`.

- [ ] **Step 3: Instantiate the VHDL core with fixed stage-1 configuration**

The wrapper instantiates:

```systemverilog
top_aes_gcm i_aes_gcm (...);
```

The imported generated `top_aes_gcm.vhd` binds the AES-256 configuration and
supplies a medium seven-round physical datapath. The wrapper drives
`aes_gcm_mode_i = 2'b10` and pulses a local core reset for each operation so
an empty GCM packet cannot inherit GHASH state from a preceding transaction.

- [ ] **Step 4: Add sources and top-level instance**

Add the third-party VHDL files in dependency order to the root `Makefile`
generator for `scripts/add_sources.tcl`, read the SystemVerilog wrapper, and instantiate it on
`master[ariane_soc::AESGCM]` with `aes_irq`.

- [ ] **Step 5: Run a Vivado elaboration/build**

Run from the WSL orchestration layer:

```sh
cd /home/carlos/projects/CHAOS
fpga/sync-cva6-to-windows.sh
fpga/build-cva6-zcu111-win-vivado.sh
```

Expected: Vivado produces a ZCU111 bitstream without unresolved VHDL/SV
bindings and without regressions in implemented timing checks.

### Task 5: Validate AES-GCM On The Board

**Files:**
- Modify: `corev_apu/fpga/tests/README.md`
- Modify: `corev_apu/fpga/tests/test-11-busybox-initramfs/README.md`

- [ ] **Step 1: Program and boot the updated design**

Program the generated `.bit`, start OpenOCD, and run:

```sh
corev_apu/fpga/tests/test-11-busybox-initramfs/run.sh
```

- [ ] **Step 2: Run regressions and KAT from Linux**

At the BusyBox shell:

```sh
cd /root
./mmio-test
./irq-test
./aes-gcm-test
```

Expected:

```text
PASS: PL peripheral MMIO test completed
PASS: PL peripheral IRQ test completed
PASS: AES-256-GCM MMIO/IRQ known-answer tests completed
```

- [ ] **Step 3: Tag the stage-1 board milestone**

After the UART outputs are captured in documentation:

```sh
git tag -a zcu111-aes-gcm-kat -m "ZCU111 AES-GCM MMIO/IRQ KAT validated on hardware"
git push origin zcu111-aes-gcm
git push origin zcu111-aes-gcm-kat
```

## Deferred Stage-2 Plan Gate

After `zcu111-aes-gcm-kat` is validated, write the separate DDR4 throughput
plan. It must add AXI master/DMA-style buffer movement, retain these control
registers where applicable, validate KAT through DDR buffers, and measure
throughput/timing/resource use before creating
`zcu111-aes-gcm-ddr-throughput`.
