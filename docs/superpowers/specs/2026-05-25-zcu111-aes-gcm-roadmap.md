# ZCU111 CVA6 AES-GCM And System Viability Roadmap

Date: 2026-05-25

## Goal

Extend the validated CVA6-on-ZCU111 Linux platform with a functional AES-GCM
accelerator in programmable logic, then use it as part of a realistic
architecture feasibility study for a future Vantelis system.

This milestone remains focused on proving hardware/software integration and
measuring useful behavior. It does not attempt to define a production security
boundary, key-management architecture, or final boot medium.

## Validated Baseline

The new work starts from branch `zcu111-pl-peripherals`, tag
`zcu111-pl-irq-smoke`, commit `38e5ee5d`.

Already validated on the ZCU111:

- CVA6 executes bare-metal tests through OpenOCD/GDB and prints through UART.
- PL DDR4 is mapped at `0x8000_0000` and has passed bare-metal sweeps and
  Linux userland memory stress through 768 MiB.
- OpenSBI starts Linux from DDR4.
- Linux boots into a BusyBox initramfs shell over UART.
- Linux userland runs CoreMark and DDR4 `memstress`.
- A PL MMIO peripheral at `0x5000_0000` is visible from Linux.
- The PL peripheral interrupt reaches Linux through PLIC source `8` and UIO.

The proven MMIO/interrupt path is the starting control path for AES-GCM.

## Branch And Milestone Policy

This hardware feature is developed on branch `zcu111-aes-gcm`, created from
the PL interrupt milestone.

Expected milestone tags:

- `zcu111-aes-gcm-kat`: stage 1 passes known-answer tests from Linux.
- `zcu111-aes-gcm-ddr-throughput`: stage 2 processes DDR4 buffers and reports
  throughput and resource/timing results.
- `zcu111-ethernet-link`: future Ethernet hardware and Linux connectivity.
- `zcu111-ethernet-aes-gcm-path`: future combined traffic and crypto data path.

The prior tags remain immutable fallbacks; no validated milestone is replaced
in place.

## AES-GCM Stage 1: Functional Control Path

### Objective

Prove that Linux can configure an AES-GCM engine in PL, submit a small
operation, receive completion through the existing interrupt path, and verify
the cryptographic result against published vectors.

### Hardware Scope

- Place the AES-GCM control window behind the existing PL MMIO region or as an
  adjacent explicitly mapped region.
- Preserve the diagnostic peripheral on PLIC source `8` and assign AES-GCM
  completion to adjacent PLIC source `9`, using the same Linux UIO method.
  Sharing one UIO interrupt between both devices would prevent Linux tests
  from identifying which device asserted it.
- Provide registers for identification, status, command, interrupt
  enable/acknowledge, key, IV/nonce, AAD, payload input, payload output, and
  authentication tag.
- Support one bounded transaction held in registers for this phase; data
  movement performance is intentionally outside stage 1.

### Software And Verification Scope

- Extend the device tree and BusyBox initramfs test content only as required
  for the accelerator UIO device and test executable.
- Add a Linux userland `aes-gcm-test` utility.
- Use NIST AES-GCM known-answer vectors covering encryption, decryption,
  authentication-tag generation, and authentication failure behavior.
- Treat a correct result plus observed interrupt completion as the stage gate.

### Non-Goal

An MMIO word-at-a-time interface is not a throughput result. It validates
control, functional correctness, and interrupt delivery only.

## AES-GCM Stage 2: DDR4 Data Path And Measurement

### Objective

Process buffers located in PL DDR4 without requiring the CPU to shuttle each
data word through MMIO, so that measured results reflect an accelerator data
path rather than register-access overhead.

### Hardware Scope

- Add a DDR4-capable data movement path, using an AXI master/DMA-style engine
  or an equivalent controlled memory reader/writer attached to the existing
  DDR AXI infrastructure.
- Use command registers for source address, destination address, AAD location
  or bounded AAD register input, length, mode, and completion status.
- Keep result tag and error status readable through MMIO and completion visible
  through the proven IRQ path.

### Software And Verification Scope

- Extend the Linux userland test to allocate/populate DDR-backed input and
  output buffers and submit transactions.
- Re-run known-answer tests through the DDR path before collecting performance
  numbers.
- Measure latency and throughput for message sizes relevant to packet traffic,
  together with CPU involvement during submission and completion.
- Record Vivado utilization and timing after synthesis/implementation.

### Stage Gate

Stage 2 is complete only when encryption and authenticated decryption pass
known-answer vectors through DDR4 buffers, completion interrupts work
reliably, and measured throughput/resource/timing results are documented.

## Candidate AES-GCM IP Assessment

Candidate repository:
`https://github.com/BLu85/AES-GCM-128-192-256-bits`

Initial assessment:

- It implements encryption and decryption AES-GCM in VHDL.
- It exposes AES key sizes of 128, 192, and 256 bits and 96-bit IV handling.
- It contains GHASH/tag generation and a streaming 128-bit data interface.
- It provides configurable size/pipelining tradeoffs and Cocotb/GHDL tests.
- Its README reports Xilinx implementation data ranging from a compact
  configuration to a 128-bit-per-clock configuration.

Integration conditions:

- Confirm the applicable license text and preserve required attribution before
  importing any RTL. The README displays an Apache 2.0 license badge, but a
  complete license file must be verified for repository inclusion.
- Run the upstream testbench, or reproduce equivalent NIST vectors, before
  wrapping the IP in the CVA6 SoC.
- Isolate the imported IP and its wrapper so that another audited core can
  replace it without changing Linux-visible registers.

The existing `core/aes.sv` is not a substitute for this PL accelerator: it
implements RISC-V scalar cryptography instruction support inside CVA6, not an
AES-GCM streaming peripheral with GHASH and DDR data movement.

## Following System Stages

After the two AES-GCM milestones:

1. Add an Ethernet-capable PL/Linux path and validate link, addressing, ping,
   sustained data transfer, interrupts, and resource use.
2. Build a combined representative pipeline in which traffic is buffered in
   DDR4 and processed by AES-GCM, then measure throughput and latency.
3. Stabilize the hardware/software contract and create a Yocto Linux BSP path
   using the validated OpenSBI, device tree, kernel configuration, and
   userland diagnostic tools.
4. Optimize core, AXI, and memory clocks only after functional milestones are
   reproducible, since frequency work changes timing risk and performance
   interpretation.

Reducing dependence on JTAG is optional and is not on the immediate execution
path; it does not block crypto, Ethernet, or Yocto feasibility measurements.

## Immediate Execution Sequence

1. Select an attributable AES-GCM RTL core and fix AES-256-GCM as the stage-1
   key/mode subset to test first.
2. Define the stable Linux-visible AES-GCM register interface and the NIST KAT
   set that must pass.
3. Implement and simulate the stage-1 RTL wrapper and userland test.
4. Build the ZCU111 bitstream and validate KAT plus IRQ on the board.
5. Design and implement the DDR4 data mover for stage 2.
6. Validate DDR-backed KAT, throughput, timing, and resource use on hardware.
