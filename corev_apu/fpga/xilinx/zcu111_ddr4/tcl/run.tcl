set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD)

set ipName zcu111_ddr4

create_project $ipName . -force -part $partNumber
if {$boardName ne "none"} {
    set_property board_part $boardName [current_project]
}

create_ip -name ddr4 -vendor xilinx.com -library ip -module_name $ipName

# ZCU111 PL DDR4: four Micron MT40A512M16JY-075E components, 64-bit bus.
# Vivado 2025.2 does not list the exact JY part; HA is the closest supported
# 8Gb x16 075E component class and keeps the generated controller in the same
# electrical/timing family for first hardware bring-up.
set_property -dict [list \
    CONFIG.C0.DDR4_MemoryType {Components} \
    CONFIG.C0.DDR4_MemoryPart {MT40A512M16HA-075E} \
    CONFIG.C0.DDR4_DataWidth {64} \
    CONFIG.C0.DDR4_DataMask {DM_NO_DBI} \
    CONFIG.C0.DDR4_Ecc {false} \
    CONFIG.C0.DDR4_AxiSelection {true} \
    CONFIG.C0.DDR4_AxiAddressWidth {32} \
    CONFIG.C0.DDR4_AxiDataWidth {512} \
    CONFIG.C0.DDR4_AxiIDWidth {4} \
    CONFIG.C0.DDR4_TimePeriod {833} \
    CONFIG.C0.DDR4_InputClockPeriod {3332} \
    CONFIG.System_Clock {Differential} \
    CONFIG.C0_CLOCK_BOARD_INTERFACE {Custom} \
    CONFIG.C0_DDR4_BOARD_INTERFACE {Custom} \
] [get_ips $ipName]

generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
