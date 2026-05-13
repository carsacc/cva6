## ZCU111 phase-1 bare-metal constraints.
## External DDR4, SD, Ethernet, RFDC, and DPTI are intentionally not constrained.

## CLK_100 fixed 100 MHz LVDS clock, U46 -> U1 bank 64.
## USER_SI570/J19/J18 is also available, but shares bank 69 with PMOD_1/J49.
set_property -dict {PACKAGE_PIN AM15 IOSTANDARD LVDS} [get_ports sys_clk_p]
set_property -dict {PACKAGE_PIN AN15 IOSTANDARD LVDS} [get_ports sys_clk_n]
create_clock -period 10.000 -name sys_clk_pin [get_ports sys_clk_p]

## CPU reset pushbutton, active high.
set_property -dict {PACKAGE_PIN AF15 IOSTANDARD LVCMOS18} [get_ports cpu_reset]
set_false_path -from [get_ports cpu_reset]

## X-HEEP programmer UART0 through ZCU111 PMOD_1/J49.
## Programmer TX0 -> FPGA RXD on PMOD1_4 / J49.2.
set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVCMOS12} [get_ports rx]
## FPGA TXD -> programmer RX0 on PMOD1_0 / J49.1.
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS12} [get_ports tx]

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
## X-HEEP ADBUS0 TCK -> ZCU111 PMOD1_5 / J49.4.
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS12} [get_ports tck]
## PMOD TCK is not on a dedicated clock route; this matches other CVA6 PMOD JTAG boards.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets tck_IBUF_inst/O]
## X-HEEP ADBUS3 TMS -> ZCU111 PMOD1_2 / J49.5.
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS12} [get_ports tms]
## X-HEEP ADBUS1 TDI -> ZCU111 PMOD1_1 / J49.3.
set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS12} [get_ports tdi]
## ZCU111 PMOD1_6 / J49.6 -> X-HEEP ADBUS2 TDO.
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS12} [get_ports tdo]
