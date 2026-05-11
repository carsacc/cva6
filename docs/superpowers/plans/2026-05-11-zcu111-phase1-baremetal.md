# ZCU111 Phase 1 Bare-Metal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first ZCU111 FPGA target that boots CVA6 bare-metal from local AXI BRAM/URAM memory without using external DDR4.

**Architecture:** Reuse the existing CVA6 APU FPGA top and build flow, adding `BOARD=zcu111` as a generated Vivado target. The first target keeps UART, RISC-V JTAG debug, GPIO LEDs/switches, CLINT, PLIC, timer, ROM, and a local AXI memory mapped at `0x8000_0000`; DDR4, Ethernet, SD, SPI, and DPTI are excluded for this phase.

**Tech Stack:** SystemVerilog RTL, Xilinx Vivado 2022.2, CVA6 Makefile flow, AMD ZCU111 UG1271 board constraints, OpenOCD/GDB for bare-metal validation.

---

## File Structure

- `Makefile`: add `BOARD=zcu111` with the XCZU28DR part and no required board-part metadata.
- `corev_apu/fpga/Makefile`: use a reduced IP set for ZCU111 phase 1.
- `corev_apu/fpga/scripts/prologue.tcl`: allow `XILINX_BOARD=none` so the build does not require an installed ZCU111 board file.
- `corev_apu/fpga/scripts/run.tcl`: add the ZCU111 constraints/header branch and conditional IP loading.
- `corev_apu/fpga/xilinx/xlnx_clk_gen/tcl/run.tcl`: add a ZCU111 clock-wizard configuration for 300 MHz USER_SI570 input.
- `corev_apu/fpga/src/zcu111.svh`: define the ZCU111 board macro and basic FPGA settings.
- `corev_apu/fpga/constraints/zcu111.xdc`: constrain phase-1 clock, reset, LEDs, switches, and X-HEEP-programmer-hosted UART/JTAG on ZCU111 `PMOD_1`/J49.
- `corev_apu/fpga/constraints/ariane_dpti.xdc`: move the existing DPTI `prog_*` timing constraints out of the common XDC so ZCU111 can omit DPTI ports cleanly.
- `corev_apu/fpga/src/ariane_xilinx.sv`: add a ZCU111 top-level port branch, disable non-phase-1 external ports for ZCU111, instantiate the 300 MHz input buffer/clock wizard, and replace DDR with local AXI memory for ZCU111.
- `docs/superpowers/specs/2026-05-11-zcu111-cva6-bringup-design.md`: already committed design reference.

Board facts used by this plan:

- ZCU111 uses `XCZU28DR-2E FFVG1517`.
- USER_SI570 defaults to 300 MHz and connects to U1 pins `J19/J18`.
- Phase 1 uses the external X-HEEP programmer PMOD for UART0 and RISC-V JTAG, not the ZCU111 onboard FT4232HL UART2 PL path on `AT15/AU15`.
- User LEDs `GPIO_LED[0..7]` use U1 pins `AR13 AP13 AR16 AP16 AP15 AN16 AN17 AV15`.
- User DIP switches `GPIO_DIP_SW[0..7]` use U1 pins `AF16 AF17 AH15 AH16 AH17 AG17 AJ15 AJ16`.
- CPU reset uses U1 pin `AF15`.
- Nomenclature note: the ZCU111 calls its headers `PMOD_0`/J48 and `PMOD_1`/J49; the EPFL X-HEEP programmer calls its headers `PMOD_1` for UART/JTAG and `PMOD_2` for SPI/flash.
- ZCU111 `PMOD_1`/J49 connects to U1 pins `L14 L15 M13 N13 M15 N15 M14 N14`, all `LVCMOS12`.
- ZCU111 `PMOD_1`/J49 mapping from UG1271:
  - `PMOD1_0`: U1 `L14`, J49.1
  - `PMOD1_1`: U1 `L15`, J49.3
  - `PMOD1_2`: U1 `M13`, J49.5
  - `PMOD1_3`: U1 `N13`, J49.7
  - `PMOD1_4`: U1 `M15`, J49.2
  - `PMOD1_5`: U1 `N15`, J49.4
  - `PMOD1_6`: U1 `M14`, J49.6
  - `PMOD1_7`: U1 `N14`, J49.8
- X-HEEP programmer PMOD physical alignment for Carlos's board:
  - EPFL programmer `PMOD_2` aligns with ZCU111 `PMOD_0`/J48 and is reserved for SPI/flash, unused in phase 1.
  - EPFL programmer `PMOD_1` aligns with ZCU111 `PMOD_1`/J49 and carries RISC-V JTAG plus UART0.
  - expected straight-through signal mapping: J49.1=`rx` from programmer `TX0`, J49.2=`tx` to programmer `RX0`, J49.3=`tck`, J49.4=`tdi`, J49.5=`tdo`, J49.6=`tms`; J49.7/J49.8 are programmer auxiliary GPIO and are unused.
- ZCU111 `PMOD_1`/J49 level shifter is confirmed as `TXS0108E`, compatible with bidirectional JTAG use.
- EPFL programmer continuity is confirmed: `PMOD_1` pin 1 to FT4232H pin 38 (`CDBUS0/TX0`), and `PMOD_1` pin 3 to FT4232H pin 16 (`ADBUS0/TCK`).

Sources:

- AMD UG1271 Board Features: https://docs.amd.com/r/en-US/ug1271-zcu111-eval-bd/Board-Features
- AMD UG1271 Programmable User SI570 Clock: https://docs.amd.com/r/en-US/ug1271-zcu111-eval-bd/Programmable-User-SI570-Clock
- AMD UG1271 User I/O: https://docs.amd.com/r/en-US/ug1271-zcu111-eval-bd/User-I/O
- AMD UG1271 User PMOD GPIO Connectors: https://docs.amd.com/r/en-US/ug1271-zcu111-eval-bd/User-PMOD-GPIO-Connectors
- X-HEEP programmer PMOD repository: https://github.com/esl-epfl/x-heep-programmer-pmod
- X-HEEP programmer FT4232H VID/PID documentation: https://x-heep.readthedocs.io/en/stable/How_to/ProgramFlash.html

---

### Task 1: Add ZCU111 Board Selection To The Build Flow

**Files:**
- Modify: `Makefile`
- Modify: `corev_apu/fpga/scripts/prologue.tcl`

- [ ] **Step 1: Add the board case in the top-level Makefile**

In `Makefile`, extend the board selection block near the existing `genesys2`, `kc705`, `vc707`, and `nexys_video` branches:

```make
else ifeq ($(BOARD), zcu111)
	XILINX_PART              := xczu28dr-ffvg1517-2-e
	XILINX_BOARD             := none
	CLK_PERIOD_NS            := 20
```

Place it before the final `else` that reports `Unknown board`.

- [ ] **Step 2: Allow no board-part in Vivado prologue**

In `corev_apu/fpga/scripts/prologue.tcl`, replace:

```tcl
set_property board_part $::env(XILINX_BOARD) [current_project]
```

with:

```tcl
if {[info exists ::env(XILINX_BOARD)] && $::env(XILINX_BOARD) ne "none"} {
    set_property board_part $::env(XILINX_BOARD) [current_project]
}
```

- [ ] **Step 3: Verify Makefile expansion**

Run:

```bash
RISCV=/tmp/nonexistent make -n BOARD=zcu111 fpga
```

Expected:

- The dry run reaches the FPGA build command.
- The output contains `BOARD=zcu111`.
- The output contains `XILINX_PART=xczu28dr-ffvg1517-2-e`.
- The command does not fail with `Unknown board`.

- [ ] **Step 4: Commit**

```bash
git add Makefile corev_apu/fpga/scripts/prologue.tcl
git commit -m "build: add zcu111 board selection"
```

---

### Task 2: Add ZCU111 Phase-1 Constraints And Header

**Files:**
- Create: `corev_apu/fpga/src/zcu111.svh`
- Create: `corev_apu/fpga/constraints/zcu111.xdc`
- Modify: `corev_apu/fpga/scripts/run.tcl`

- [ ] **Step 1: Create the ZCU111 header**

Create `corev_apu/fpga/src/zcu111.svh`:

```systemverilog
`define ZCU111
`define ARIANE_DATA_WIDTH 64
```

- [ ] **Step 2: Create the phase-1 XDC**

Create `corev_apu/fpga/constraints/zcu111.xdc`:

```tcl
## ZCU111 phase-1 bare-metal constraints.
## External DDR4, SD, Ethernet, RFDC, and DPTI are intentionally not constrained.

## USER_SI570 default 300 MHz LVDS clock, U47 -> U1 bank 69.
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVDS} [get_ports sys_clk_p]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVDS} [get_ports sys_clk_n]
create_clock -period 3.333 -name sys_clk_pin [get_ports sys_clk_p]

## CPU reset pushbutton, active high.
set_property -dict {PACKAGE_PIN AF15 IOSTANDARD LVCMOS18} [get_ports cpu_reset]
set_false_path -from [get_ports cpu_reset]

## X-HEEP programmer UART0 through ZCU111 PMOD_1/J49.
## Programmer TX0 -> FPGA RXD on PMOD1_0 / J49.1.
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS12} [get_ports rx]
## FPGA TXD -> programmer RX0 on PMOD1_4 / J49.2.
set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVCMOS12} [get_ports tx]

## User LEDs, active high.
set_property -dict {PACKAGE_PIN AR13 IOSTANDARD LVCMOS18} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN AP13 IOSTANDARD LVCMOS18} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN AR16 IOSTANDARD LVCMOS18} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN AP16 IOSTANDARD LVCMOS18} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN AP15 IOSTANDARD LVCMOS18} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN AN16 IOSTANDARD LVCMOS18} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN AN17 IOSTANDARD LVCMOS18} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN AV15 IOSTANDARD LVCMOS18} [get_ports {led[7]}]

## User DIP switches, active high.
set_property -dict {PACKAGE_PIN AF16 IOSTANDARD LVCMOS18} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN AF17 IOSTANDARD LVCMOS18} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN AH15 IOSTANDARD LVCMOS18} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN AH16 IOSTANDARD LVCMOS18} [get_ports {sw[3]}]
set_property -dict {PACKAGE_PIN AH17 IOSTANDARD LVCMOS18} [get_ports {sw[4]}]
set_property -dict {PACKAGE_PIN AG17 IOSTANDARD LVCMOS18} [get_ports {sw[5]}]
set_property -dict {PACKAGE_PIN AJ15 IOSTANDARD LVCMOS18} [get_ports {sw[6]}]
set_property -dict {PACKAGE_PIN AJ16 IOSTANDARD LVCMOS18} [get_ports {sw[7]}]

## RISC-V debug JTAG through X-HEEP programmer PMOD_1 -> ZCU111 PMOD_1/J49.
## JTAG timing constraints are inherited from constraints/ariane.xdc.
## X-HEEP ADBUS0 TCK -> ZCU111 PMOD1_1 / J49.3.
set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS12} [get_ports tck]
## X-HEEP ADBUS3 TMS -> ZCU111 PMOD1_6 / J49.6.
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS12} [get_ports tms]
## X-HEEP ADBUS1 TDI -> ZCU111 PMOD1_5 / J49.4.
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS12} [get_ports tdi]
## ZCU111 PMOD1_2 / J49.5 -> X-HEEP ADBUS2 TDO.
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS12} [get_ports tdo]
```

- [ ] **Step 3: Add ZCU111 constraints and header branch to run.tcl**

In `corev_apu/fpga/scripts/run.tcl`, extend the first board-constraint selection:

```tcl
} elseif {$::env(BOARD) eq "zcu111"} {
      add_files -fileset constrs_1 -norecurse constraints/zcu111.xdc
```

In the board header selection later in the same file, add:

```tcl
} elseif {$::env(BOARD) eq "zcu111"} {
      read_verilog -sv {src/zcu111.svh ../../vendor/pulp-platform/common_cells/include/common_cells/registers.svh}
      set file "src/zcu111.svh"
      set registers "../../vendor/pulp-platform/common_cells/include/common_cells/registers.svh"
```

- [ ] **Step 4: Verify source references**

Run:

```bash
rg -n "zcu111|ZCU111" corev_apu/fpga/src/zcu111.svh corev_apu/fpga/constraints/zcu111.xdc corev_apu/fpga/scripts/run.tcl
```

Expected:

- The output shows `define ZCU111`.
- The output shows `constraints/zcu111.xdc`.
- The output shows the `BOARD` branch for `zcu111`.

- [ ] **Step 5: Commit**

```bash
git add corev_apu/fpga/src/zcu111.svh corev_apu/fpga/constraints/zcu111.xdc corev_apu/fpga/scripts/run.tcl
git commit -m "fpga: add zcu111 phase1 board files"
```

---

### Task 2.5: Split Common And DPTI Constraints

**Files:**
- Modify: `corev_apu/fpga/constraints/ariane.xdc`
- Create: `corev_apu/fpga/constraints/ariane_dpti.xdc`
- Modify: `corev_apu/fpga/scripts/run.tcl`

- [ ] **Step 1: Move DPTI timing constraints out of ariane.xdc**

In `corev_apu/fpga/constraints/ariane.xdc`, keep the JTAG/DMI timing block and the existing `DONT_TOUCH` properties, but remove the `prog_clko`/`prog_*` DPTI block:

```tcl
create_clock -period 16.667 -name prog_clko_pin -waveform {0.000 8.333} [get_ports prog_clko]

set_input_delay -clock [get_clocks prog_clko_pin] -min -add_delay 1.000 [get_ports {prog_d[*]}]
set_input_delay -clock [get_clocks prog_clko_pin] -max -add_delay 7.150 [get_ports {prog_d[*]}]
set_input_delay -clock [get_clocks prog_clko_pin] -min -add_delay 1.000 [get_ports prog_rxen]
set_input_delay -clock [get_clocks prog_clko_pin] -max -add_delay 7.150 [get_ports prog_rxen]
set_input_delay -clock [get_clocks prog_clko_pin] -min -add_delay 1.000 [get_ports prog_txen]
set_input_delay -clock [get_clocks prog_clko_pin] -max -add_delay 7.150 [get_ports prog_txen]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports {prog_d[*]}]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports {prog_d[*]}]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports prog_oen]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports prog_oen]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports prog_rdn]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports prog_rdn]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports prog_wrn]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports prog_wrn]

set_property IOB TRUE [get_ports {prog_d[*]}]
set_property IOB TRUE [get_ports prog_rxen]
set_property IOB TRUE [get_ports prog_txen]
```

- [ ] **Step 2: Create the DPTI-only XDC**

Create `corev_apu/fpga/constraints/ariane_dpti.xdc` with exactly the block removed in Step 1:

```tcl
## DPTI timing constraints. Boards without DPTI ports, such as ZCU111 phase 1,
## must not load this file.

create_clock -period 16.667 -name prog_clko_pin -waveform {0.000 8.333} [get_ports prog_clko]

set_input_delay -clock [get_clocks prog_clko_pin] -min -add_delay 1.000 [get_ports {prog_d[*]}]
set_input_delay -clock [get_clocks prog_clko_pin] -max -add_delay 7.150 [get_ports {prog_d[*]}]
set_input_delay -clock [get_clocks prog_clko_pin] -min -add_delay 1.000 [get_ports prog_rxen]
set_input_delay -clock [get_clocks prog_clko_pin] -max -add_delay 7.150 [get_ports prog_rxen]
set_input_delay -clock [get_clocks prog_clko_pin] -min -add_delay 1.000 [get_ports prog_txen]
set_input_delay -clock [get_clocks prog_clko_pin] -max -add_delay 7.150 [get_ports prog_txen]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports {prog_d[*]}]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports {prog_d[*]}]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports prog_oen]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports prog_oen]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports prog_rdn]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports prog_rdn]
set_output_delay -clock [get_clocks prog_clko_pin] -min -add_delay 0.400 [get_ports prog_wrn]
set_output_delay -clock [get_clocks prog_clko_pin] -max -add_delay 8.600 [get_ports prog_wrn]

set_property IOB TRUE [get_ports {prog_d[*]}]
set_property IOB TRUE [get_ports prog_rxen]
set_property IOB TRUE [get_ports prog_txen]
```

- [ ] **Step 3: Conditionally load DPTI constraints**

In `corev_apu/fpga/scripts/run.tcl`, immediately after:

```tcl
add_files -fileset constrs_1 -norecurse constraints/$project.xdc
```

add:

```tcl
if {$::env(BOARD) ne "zcu111"} {
      add_files -fileset constrs_1 -norecurse constraints/ariane_dpti.xdc
}
```

- [ ] **Step 4: Verify DPTI constraints are split**

Run:

```bash
rg -n "prog_clko|prog_d|prog_rxen|prog_txen" corev_apu/fpga/constraints
```

Expected:

- `prog_clko` appears in `corev_apu/fpga/constraints/ariane_dpti.xdc`.
- `prog_clko` does not appear in `corev_apu/fpga/constraints/ariane.xdc`.
- `corev_apu/fpga/constraints/zcu111.xdc` does not contain `create_clock -name tck`; JTAG timing comes from `ariane.xdc`.

- [ ] **Step 5: Commit**

```bash
git add corev_apu/fpga/constraints/ariane.xdc corev_apu/fpga/constraints/ariane_dpti.xdc corev_apu/fpga/scripts/run.tcl
git commit -m "fpga: split dpti constraints from common xdc"
```

---

### Task 3: Reduce Xilinx IP Generation For ZCU111 Phase 1

**Files:**
- Modify: `corev_apu/fpga/Makefile`
- Modify: `corev_apu/fpga/scripts/run.tcl`
- Modify: `corev_apu/fpga/xilinx/xlnx_clk_gen/tcl/run.tcl`

- [ ] **Step 1: Make the phase-1 IP list board-dependent**

In `corev_apu/fpga/Makefile`, replace the current unconditional `ips := ...` block with:

```make
ifeq ($(BOARD), zcu111)
ips := xlnx_axi_dwidth_converter.xci \
       xlnx_axi_gpio.xci             \
       xlnx_clk_gen.xci
else
ips := xlnx_axi_clock_converter.xci  \
       xlnx_axi_dwidth_converter.xci \
       xlnx_axi_dwidth_converter_dm_master.xci \
       xlnx_axi_dwidth_converter_dm_slave.xci \
       xlnx_axi_quad_spi.xci         \
       xlnx_axi_gpio.xci             \
       xlnx_clk_gen.xci              \
       xlnx_dpti_clk.xci             \
       xlnx_mig_7_ddr3.xci
endif
```

Keep the existing `ips := $(addprefix $(work-dir)/, $(ips))` lines after this block.

- [ ] **Step 2: Load only phase-1 IPs for ZCU111**

In `corev_apu/fpga/scripts/run.tcl`, wrap the `read_ip` section:

```tcl
if {$::env(BOARD) eq "zcu111"} {
  read_ip { \
        "xilinx/xlnx_axi_dwidth_converter/xlnx_axi_dwidth_converter.srcs/sources_1/ip/xlnx_axi_dwidth_converter/xlnx_axi_dwidth_converter.xci" \
        "xilinx/xlnx_axi_gpio/xlnx_axi_gpio.srcs/sources_1/ip/xlnx_axi_gpio/xlnx_axi_gpio.xci" \
        "xilinx/xlnx_clk_gen/xlnx_clk_gen.srcs/sources_1/ip/xlnx_clk_gen/xlnx_clk_gen.xci" \
  }
} else {
  read_ip { \
        "xilinx/xlnx_mig_7_ddr3/xlnx_mig_7_ddr3.srcs/sources_1/ip/xlnx_mig_7_ddr3/xlnx_mig_7_ddr3.xci" \
        "xilinx/xlnx_axi_clock_converter/xlnx_axi_clock_converter.srcs/sources_1/ip/xlnx_axi_clock_converter/xlnx_axi_clock_converter.xci" \
        "xilinx/xlnx_axi_dwidth_converter/xlnx_axi_dwidth_converter.srcs/sources_1/ip/xlnx_axi_dwidth_converter/xlnx_axi_dwidth_converter.xci" \
        "xilinx/xlnx_axi_dwidth_converter_dm_slave/xlnx_axi_dwidth_converter_dm_slave.srcs/sources_1/ip/xlnx_axi_dwidth_converter_dm_slave/xlnx_axi_dwidth_converter_dm_slave.xci" \
        "xilinx/xlnx_axi_dwidth_converter_dm_master/xlnx_axi_dwidth_converter_dm_master.srcs/sources_1/ip/xlnx_axi_dwidth_converter_dm_master/xlnx_axi_dwidth_converter_dm_master.xci" \
        "xilinx/xlnx_axi_gpio/xlnx_axi_gpio.srcs/sources_1/ip/xlnx_axi_gpio/xlnx_axi_gpio.xci" \
        "xilinx/xlnx_axi_quad_spi/xlnx_axi_quad_spi.srcs/sources_1/ip/xlnx_axi_quad_spi/xlnx_axi_quad_spi.xci" \
        "xilinx/xlnx_clk_gen/xlnx_clk_gen.srcs/sources_1/ip/xlnx_clk_gen/xlnx_clk_gen.xci" \
        "xilinx/xlnx_dpti_clk/xlnx_dpti_clk.srcs/sources_1/ip/xlnx_dpti_clk/xlnx_dpti_clk.xci" \
  }
}
```

- [ ] **Step 3: Add ZCU111 clock wizard configuration**

In `corev_apu/fpga/xilinx/xlnx_clk_gen/tcl/run.tcl`, add a first branch before the existing `nexys_video` branch:

```tcl
if {$::env(BOARD) eq "zcu111"} {
    set_property -dict [list CONFIG.PRIM_IN_FREQ {300.000} \
                        CONFIG.NUM_OUT_CLKS {4} \
                        CONFIG.CLKOUT2_USED {true} \
                        CONFIG.CLKOUT3_USED {true} \
                        CONFIG.CLKOUT4_USED {true} \
                        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50} \
                        CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {125} \
                        CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {125} \
                        CONFIG.CLKOUT3_REQUESTED_PHASE {90.000} \
                        CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {50} \
                        CONFIG.CLKIN1_JITTER_PS {50.0} \
                       ] [get_ips $ipName]
} elseif {$::env(BOARD) eq "nexys_video"} {
```

Keep the existing `nexys_video` and default branches unchanged after changing `if` to `elseif`.

- [ ] **Step 4: Verify IP list does not include DDR3 for ZCU111**

Run:

```bash
make -C corev_apu/fpga -n BOARD=zcu111 | rg "xlnx_mig_7_ddr3|xlnx_axi_clock_converter|xlnx_clk_gen|xlnx_axi_gpio"
```

Expected:

- The output includes `xlnx_clk_gen`.
- The output includes `xlnx_axi_gpio`.
- The output does not include commands to build `xlnx_mig_7_ddr3`.
- The output does not include commands to build `xlnx_axi_clock_converter`.

- [ ] **Step 5: Commit**

```bash
git add corev_apu/fpga/Makefile corev_apu/fpga/scripts/run.tcl corev_apu/fpga/xilinx/xlnx_clk_gen/tcl/run.tcl
git commit -m "fpga: reduce zcu111 phase1 xilinx ips"
```

---

### Task 4: Add ZCU111 Ports And Disable Non-Phase-1 External Interfaces

**Files:**
- Modify: `corev_apu/fpga/src/ariane_xilinx.sv`

- [ ] **Step 1: Add ZCU111 top-level port branch**

In `corev_apu/fpga/src/ariane_xilinx.sv`, add this board branch after `VCU118` and before `NEXYS_VIDEO`:

```systemverilog
`elsif ZCU111
  input  logic         sys_clk_p,
  input  logic         sys_clk_n,
  input  logic         cpu_reset,
  output logic [ 7:0]  led,
  input  logic [ 7:0]  sw,
```

- [ ] **Step 2: Exclude SPI and DPTI ports from ZCU111**

Wrap the SPI and DPTI top-level ports in `ifndef ZCU111`:

```systemverilog
`ifndef ZCU111
  // SPI
  output logic        spi_mosi,
  input  logic        spi_miso,
  output logic        spi_ss,
  output logic        spi_clk_o,
`endif
  // common part
  input  logic        tck,
  input  logic        tms,
  input  logic        tdi,
  output wire         tdo,
`ifndef ZCU111
  input  logic        prog_clko,
  input  logic        prog_rxen,
  input  logic        prog_txen,
  input  logic        prog_spien,
  output logic        prog_rdn,
  output logic        prog_wrn,
  output logic        prog_oen,
  output logic        prog_siwun,
  inout  logic [7:0]  prog_d,
`endif
  input  logic        rx,
  output logic        tx
```

Preserve the module port-list comma syntax exactly as shown.

- [ ] **Step 3: Add reset polarity for ZCU111**

In the reset polarity block, add:

```systemverilog
`elsif ZCU111
logic cpu_resetn;
assign cpu_resetn = ~cpu_reset;
```

Keep the existing `VCU118` branch unchanged. The full reset-polarity block must use valid SystemVerilog preprocessor syntax:

```systemverilog
`ifdef VCU118
logic cpu_resetn;
assign cpu_resetn = ~cpu_reset;
`elsif GENESYSII
logic cpu_reset;
assign cpu_reset  = ~cpu_resetn;
`elsif KC705
assign cpu_resetn = ~cpu_reset;
`elsif VC707
assign cpu_resetn = ~cpu_reset;
assign trst_n = ~trst;
`elsif ZCU111
logic cpu_resetn;
assign cpu_resetn = ~cpu_reset;
`elsif NEXYS_VIDEO
logic cpu_reset;
assign cpu_reset  = ~cpu_resetn;
`endif
```

- [ ] **Step 4: Add an internal JTAG TRST signal for ZCU111**

Near the debug signal declarations, add:

```systemverilog
logic jtag_trst_n;

`ifdef ZCU111
assign jtag_trst_n = cpu_resetn;
`else
assign jtag_trst_n = trst_n;
`endif
```

In the `dmi_jtag i_dmi_jtag` instance, replace:

```systemverilog
.trst_ni              ( trst_n ),
```

with:

```systemverilog
.trst_ni              ( jtag_trst_n ),
```

- [ ] **Step 5: Disable DPTI logic for ZCU111**

Wrap the `// DPTI` section in:

```systemverilog
`ifndef ZCU111
// ---------------
// DPTI
// ---------------
...
`endif
```

The wrapped region starts at the existing `// DPTI` comment and ends immediately before the `// Peripherals` comment.

- [ ] **Step 6: Add ZCU111 peripheral selection**

In the `ariane_peripherals` parameter selection, add a ZCU111 branch:

```systemverilog
    `elsif ZCU111
    .InclSPI      ( 1'b0         ),
    .InclEthernet ( 1'b0         )
```

- [ ] **Step 7: Guard unneeded Ethernet wiring for ZCU111**

In the `ariane_peripherals` instance port map, replace Ethernet external ports with ZCU111-safe constants and opens:

```systemverilog
`ifdef ZCU111
    .eth_txck      (              ),
    .eth_rxck      ( 1'b0         ),
    .eth_rxctl     ( 1'b0         ),
    .eth_rxd       ( 4'b0         ),
    .eth_rst_n     (              ),
    .eth_txctl     (              ),
    .eth_txd       (              ),
    .eth_mdio      (              ),
    .eth_mdc       (              ),
`else
    .eth_txck,
    .eth_rxck,
    .eth_rxctl,
    .eth_rxd,
    .eth_rst_n,
    .eth_txctl,
    .eth_txd,
    .eth_mdio,
    .eth_mdc,
`endif
```

Keep `spi_*` ports similarly guarded:

```systemverilog
`ifdef ZCU111
    .spi_clk_o     (              ),
    .spi_mosi      (              ),
    .spi_miso      ( 1'b0         ),
    .spi_ss        (              ),
`else
    .spi_clk_o      ( spi_clk_o   ),
    .spi_mosi       ( spi_mosi    ),
    .spi_miso       ( spi_miso    ),
    .spi_ss         ( spi_ss      ),
`endif
```

- [ ] **Step 8: Check syntax around ZCU111 guards**

Run:

```bash
rg -n "ZCU111|DPTI|InclSPI|prog_clko|spi_mosi|eth_rxck" corev_apu/fpga/src/ariane_xilinx.sv
```

Expected:

- There is one ZCU111 top-level port branch.
- SPI and DPTI external ports are guarded for ZCU111.
- The `ariane_peripherals` parameter list has a ZCU111 branch.
- `dmi_jtag.trst_ni` is driven by `jtag_trst_n`.

- [ ] **Step 9: Commit**

```bash
git add corev_apu/fpga/src/ariane_xilinx.sv
git commit -m "rtl: add zcu111 phase1 top-level ports"
```

---

### Task 5: Add ZCU111 Clocking And Local AXI Memory

**Files:**
- Modify: `corev_apu/fpga/src/ariane_xilinx.sv`

- [ ] **Step 1: Add ZCU111 clock input buffering**

Before `xlnx_clk_gen i_xlnx_clk_gen`, add a ZCU111 branch:

```systemverilog
`ifdef ZCU111
logic sys_clk_ibuf;

IBUFDS #(
  .DIFF_TERM    ( "TRUE" ),
  .IBUF_LOW_PWR ( "FALSE" )
) i_sys_clk_ibufds (
  .I  ( sys_clk_p    ),
  .IB ( sys_clk_n    ),
  .O  ( sys_clk_ibuf )
);

xlnx_clk_gen i_xlnx_clk_gen (
  .clk_out1 ( clk        ), // 50 MHz core clock
  .clk_out2 ( phy_tx_clk ), // unused in phase 1
  .clk_out3 ( eth_clk    ), // unused in phase 1
  .clk_out4 ( sd_clk_sys ), // unused in phase 1
  .reset    ( cpu_reset  ),
  .locked   ( pll_locked ),
  .clk_in1  ( sys_clk_ibuf )
);

assign clk_200MHz_ref = clk;
assign ddr_clock_out  = clk;
assign ddr_sync_reset = cpu_reset | ~pll_locked;

`elsif NEXYS_VIDEO
```

Change the existing `ifdef NEXYS_VIDEO` clock branch to `elsif NEXYS_VIDEO` and close the full chain with the existing `endif`.

- [ ] **Step 2: Add local memory signals**

Near the existing DDR signal declarations, add ZCU111-local memory wires:

```systemverilog
`ifdef ZCU111
localparam int unsigned ZCU111LocalMemWords = 131072; // 1 MiB / 8 bytes
logic                         local_mem_req;
logic                         local_mem_we;
logic [AxiAddrWidth-1:0]      local_mem_addr;
logic [AxiDataWidth/8-1:0]    local_mem_be;
logic [AxiDataWidth-1:0]      local_mem_wdata;
logic [AxiDataWidth-1:0]      local_mem_rdata;
`endif
```

- [ ] **Step 3: Bypass DDR clock converter for ZCU111**

Wrap the current `xlnx_axi_clock_converter i_xlnx_axi_clock_converter_ddr` instantiation in:

```systemverilog
`ifndef ZCU111
xlnx_axi_clock_converter i_xlnx_axi_clock_converter_ddr (
  ...
);
`endif
```

- [ ] **Step 4: Instantiate local AXI memory for ZCU111**

After the `dram` AXI interface and before the non-ZCU111 DDR controller branches, add:

```systemverilog
`ifdef ZCU111
axi2mem #(
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) i_zcu111_axi2mem (
    .clk_i  ( clk            ),
    .rst_ni ( ndmreset_n     ),
    .slave  ( dram           ),
    .req_o  ( local_mem_req  ),
    .we_o   ( local_mem_we   ),
    .addr_o ( local_mem_addr ),
    .be_o   ( local_mem_be   ),
    .data_o ( local_mem_wdata ),
    .data_i ( local_mem_rdata )
);

sram #(
    .DATA_WIDTH ( AxiDataWidth        ),
    .USER_WIDTH ( AxiUserWidth        ),
    .USER_EN    ( 1'b0                ),
    .SIM_INIT   ( "zeros"             ),
    .NUM_WORDS  ( ZCU111LocalMemWords )
) i_zcu111_local_mem (
    .clk_i   ( clk ),
    .rst_ni  ( ndmreset_n ),
    .req_i   ( local_mem_req ),
    .we_i    ( local_mem_we ),
    .addr_i  ( local_mem_addr[$clog2(ZCU111LocalMemWords)-1+$clog2(AxiDataWidth/8):$clog2(AxiDataWidth/8)] ),
    .wuser_i ( '0 ),
    .wdata_i ( local_mem_wdata ),
    .be_i    ( local_mem_be ),
    .ruser_o ( ),
    .rdata_o ( local_mem_rdata )
);

`elsif KINTEX7
```

Change the current `` `ifdef KINTEX7`` before the DDR3 controller to `` `elsif KINTEX7`` so the ZCU111 branch and existing board branches form one chain.

- [ ] **Step 5: Verify no DDR IP names are required in ZCU111 RTL path**

Run:

```bash
rg -n "ZCU111|i_zcu111_axi2mem|i_zcu111_local_mem|xlnx_axi_clock_converter|xlnx_mig_7_ddr3" corev_apu/fpga/src/ariane_xilinx.sv
```

Expected:

- The ZCU111 branch contains `i_zcu111_axi2mem`.
- The ZCU111 branch contains `i_zcu111_local_mem`.
- `xlnx_axi_clock_converter` is inside a non-ZCU111 guard.
- `xlnx_mig_7_ddr3` remains only in non-ZCU111 branches.

- [ ] **Step 6: Commit**

```bash
git add corev_apu/fpga/src/ariane_xilinx.sv
git commit -m "rtl: add zcu111 local axi memory"
```

---

### Task 6: Generate Phase-1 Sources And Run Vivado Elaboration

**Files:**
- No source edits expected.

- [ ] **Step 1: Initialize submodules**

Run:

```bash
git submodule update --init --recursive
```

Expected:

- `git submodule status --recursive` no longer shows leading `-` for required submodules.

- [ ] **Step 2: Source Vivado if needed**

Run:

```bash
source /tools/Xilinx/Vivado/2022.2/settings64.sh
vivado -version
```

Expected:

- Vivado prints version `2022.2` or a compatible installed version.

- [ ] **Step 3: Build only the generated boot ROM**

Run:

```bash
make -C corev_apu/fpga/src/bootrom BOARD=zcu111 XLEN=64 PLATFORM=PLAT_XILINX bootrom_64.sv
```

Expected:

- `corev_apu/fpga/src/bootrom/bootrom_64.sv` is generated.
- The device tree generation uses 50 MHz clock defaults for non-Agilex/non-Nexys.

- [ ] **Step 4: Generate the ZCU111 FPGA sources dry-run**

Run:

```bash
RISCV=${RISCV:?RISCV must point to the RISC-V toolchain} make -n BOARD=zcu111 fpga
```

Expected:

- The generated commands include `BOARD=zcu111`.
- The generated commands do not build `xlnx_mig_7_ddr3`.

- [ ] **Step 5: Run Vivado build through synthesis**

Run:

```bash
RISCV=${RISCV:?RISCV must point to the RISC-V toolchain} make BOARD=zcu111 fpga
```

Expected first gate:

- Vivado creates the `ariane` project.
- Source loading succeeds.
- Elaboration succeeds.

If implementation timing fails, capture the first synthesis/elaboration error before changing constraints or RTL. Phase 1 accepts a timing-debug loop after elaboration is clean.

- [ ] **Step 6: Commit build fixes**

If steps 3-5 required source edits, commit them:

```bash
git add Makefile corev_apu/fpga corev_apu/fpga/src/ariane_xilinx.sv
git commit -m "fix: make zcu111 phase1 elaborate"
```

If no source edits were needed, skip this commit.

---

### Task 7: Board Smoke Test With OpenOCD/GDB

**Files:**
- Create: `corev_apu/fpga/zcu111-pmod.cfg`
- Optional create: `corev_apu/fpga/constraints/zcu111-pmod-jtag-notes.md`

- [ ] **Step 1: Create OpenOCD config for PMOD JTAG**

Create `corev_apu/fpga/zcu111-pmod.cfg`:

```tcl
# X-HEEP programmer PMOD - JTAG channel for CVA6 debug module.
# Hardware: FT4232H, channel A ADBUS0..3 wired to EPFL programmer PMOD_1.
# EPFL programmer PMOD_1 is plugged straight-through into ZCU111 PMOD_1/J49.

adapter driver ftdi
ftdi vid_pid 0x0403 0x6011
ftdi channel 0

# ADBUS0 TCK out, ADBUS1 TDI out, ADBUS2 TDO in, ADBUS3 TMS out.
# Low-byte direction = 0b00001011 = 0x0b.
# Low-byte initial   = TMS idle high, TCK low = 0b00001000 = 0x08.
ftdi layout_init 0x0008 0x000b

# No nTRST/nSRST is exposed on the X-HEEP programmer PMOD target connector.
transport select jtag
adapter speed 1000

set _CHIPNAME riscv
jtag newtap $_CHIPNAME cpu -irlen 5 -expected-id 0x0

target create $_CHIPNAME.cpu riscv -chain-position $_CHIPNAME.cpu
riscv set_reset_timeout_sec 120
riscv set_command_timeout_sec 120
init
halt
```

The `-expected-id 0x0` value is a bootstrap placeholder. After the first successful `scan_chain`, replace it with the real CVA6 debug TAP IDCODE.

- [ ] **Step 2: Document PMOD_1 JTAG and UART wiring**

Create `corev_apu/fpga/constraints/zcu111-pmod-jtag-notes.md`:

```markdown
# ZCU111 PMOD_1 X-HEEP Programmer Wiring

Phase 1 routes CVA6 RISC-V debug JTAG and UART through the EPFL X-HEEP programmer `PMOD_1`, plugged straight-through into ZCU111 `PMOD_1`/J49.

The EPFL X-HEEP programmer `PMOD_2` aligns with ZCU111 `PMOD_0`/J48 and is reserved for SPI/flash. It is not used in phase 1.

| CVA6 Signal | X-HEEP Programmer Signal | ZCU111 Net | U1 Pin | ZCU111 PMOD Pin |
| --- | --- | --- | --- | --- |
| `rx` | `TX0` | `PMOD1_0` | `L14` | `J49.1` |
| `tx` | `RX0` | `PMOD1_4` | `M15` | `J49.2` |
| `tck` | `ADBUS0/TCK` | `PMOD1_1` | `L15` | `J49.3` |
| `tdi` | `ADBUS1/TDI` | `PMOD1_5` | `N15` | `J49.4` |
| `tdo` | `ADBUS2/TDO` | `PMOD1_2` | `M13` | `J49.5` |
| `tms` | `ADBUS3/TMS` | `PMOD1_6` | `M14` | `J49.6` |
| unused | auxiliary | `PMOD1_3` | `N13` | `J49.7` |
| unused | auxiliary | `PMOD1_7` | `N14` | `J49.8` |

The external PMOD side is 3.3 V. The ZCU111 level shifters present LVCMOS12 to the RFSoC pins, so the XDC uses `IOSTANDARD LVCMOS12` for J49.

There is no physical TRST on the X-HEEP programmer target PMOD. The ZCU111 RTL ties `dmi_jtag.trst_ni` to an internal inactive reset signal.

Hardware assumptions confirmed before programming:

- ZCU111 `PMOD_1`/J49 uses a `TXS0108E` level shifter, compatible with bidirectional JTAG use: `tck`/`tdi`/`tms` from the programmer into the RFSoC, and `tdo` from the RFSoC back to the programmer.
- EPFL programmer `PMOD_1` continuity matches its KiCad netlist: `PMOD_1` pin 1 has continuity to FT4232H pin 38 (`CDBUS0/TX0`), and `PMOD_1` pin 3 has continuity to FT4232H pin 16 (`ADBUS0/TCK`).
```

- [ ] **Step 3: Record PMOD level-shifting and programmer-continuity confirmation**

Record these already-confirmed hardware facts in `corev_apu/fpga/constraints/zcu111-pmod-jtag-notes.md`:

```markdown
## Hardware Checks

ZCU111 `PMOD_1`/J49 uses a TXS0108E level shifter. This supports the bidirectional JTAG use needed for `tck`, `tdi`, `tms`, and `tdo`.

EPFL X-HEEP programmer continuity checks passed:

- `PMOD_1` pin 1 to FT4232H pin 38 (`CDBUS0/TX0`)
- `PMOD_1` pin 3 to FT4232H pin 16 (`ADBUS0/TCK`)
```

- [ ] **Step 4: Program bitstream**

Run from `corev_apu/fpga` after a successful build:

```bash
vivado -nojournal -mode batch -source scripts/program.tcl
```

Expected:

- ZCU111 `DONE` LED indicates a loaded bitstream.

- [ ] **Step 5: Start OpenOCD**

Run:

```bash
openocd -f corev_apu/fpga/zcu111-pmod.cfg
```

Expected:

- OpenOCD reports one RISC-V hart.
- OpenOCD listens on port `3333`.

- [ ] **Step 6: Load a bare-metal ELF**

Use a small ELF linked to `0x80000000`.

Run:

```bash
${RISCV}/bin/riscv-none-elf-gdb /path/to/hello.elf
```

Inside GDB:

```gdb
target remote localhost:3333
load
b main
c
```

Expected:

- GDB loads sections into `0x8000_0000`.
- Execution reaches `main`.
- The program writes UART output at `115200` baud or toggles LEDs.

- [ ] **Step 7: Commit board smoke-test docs**

```bash
git add corev_apu/fpga/zcu111-pmod.cfg corev_apu/fpga/constraints/zcu111-pmod-jtag-notes.md
git commit -m "docs: add zcu111 phase1 debug wiring"
```

---

## Self-Review

Spec coverage:

- Phase 1 `BOARD=zcu111` flow: Tasks 1-3.
- ZCU111 header and constraints: Task 2.
- JTAG, UART, LEDs, switches: Tasks 2, 4, and 7.
- Local AXI memory at `0x8000_0000`: Task 5.
- Exclusion of DDR4, SD, Ethernet, SPI, DPTI: Tasks 3-5.
- Bare-metal validation: Tasks 6-7.

Placeholder scan:

- No placeholder markers or unspecified file paths are intentionally present.
- Board pin choices cite AMD UG1271 sections in the plan header.

Residual risks:

- OpenOCD adapter settings are specific to the X-HEEP programmer FT4232H channel A on EPFL programmer `PMOD_1`; the RISC-V target section remains reusable if the adapter section changes.
- ZCU111 `PMOD_1`/J49 level shifter and EPFL programmer continuity are confirmed; if the board/programmer hardware changes, repeat Task 7 Step 3.
- Vivado timing may require additional constraints after clean elaboration.
- Local memory size may need to be reduced if implementation utilization is too high with CVA6 on XCZU28DR.
