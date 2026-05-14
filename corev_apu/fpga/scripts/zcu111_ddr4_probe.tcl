set project zcu111_ddr4_probe
set ip_name zcu111_ddr4_probe_ip

create_project $project . -force -part $::env(XILINX_PART)

create_ip -name ddr4 -vendor xilinx.com -library ip -module_name $ip_name

set_property -dict [list \
  CONFIG.C0.DDR4_MemoryType {Components} \
  CONFIG.C0.DDR4_MemoryPart {MT40A512M16HA-075E} \
  CONFIG.C0.DDR4_DataWidth {64} \
  CONFIG.C0.DDR4_AxiSelection {true} \
] [get_ips $ip_name]

set rpt_dir reports
file mkdir $rpt_dir

set rpt [open "$rpt_dir/zcu111_ddr4_probe.rpt" w]
puts $rpt "Vivado DDR4 IP probe"
puts $rpt "part: $::env(XILINX_PART)"
puts $rpt ""
puts $rpt "CONFIG properties:"
foreach prop [lsort [list_property [get_ips $ip_name] CONFIG.*]] {
  puts $rpt [format "%-60s %s" $prop [get_property $prop [get_ips $ip_name]]]
}
close $rpt

generate_target {instantiation_template} [get_files ./$project.srcs/sources_1/ip/$ip_name/$ip_name.xci]
generate_target all [get_files ./$project.srcs/sources_1/ip/$ip_name/$ip_name.xci]

set inst_tpl [glob -nocomplain ./$project.srcs/sources_1/ip/$ip_name/*_inst.v*]
set rpt [open "$rpt_dir/zcu111_ddr4_instantiation_template.rpt" w]
foreach f $inst_tpl {
  puts $rpt "===== $f ====="
  set fd [open $f r]
  puts $rpt [read $fd]
  close $fd
}
close $rpt

exit
