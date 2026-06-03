set pagination off
set confirm off
set architecture riscv:rv64
set remotetimeout 120
set target-async on

target extended-remote localhost:3333
monitor halt
# Start every boot attempt from a clean hart/debug-module state. Re-running
# while a previous Linux instance has satp enabled can otherwise resume OpenSBI
# with stale supervisor/MMU state.
monitor riscv dmi_write 0x10 0x00000003
monitor sleep 10
monitor riscv dmi_write 0x10 0x80000001
monitor sleep 10
monitor halt
monitor riscv dmi_write 0x10 0x00000001

file ${FW_JUMP_ELF}
load

restore ${LINUX_IMAGE} binary 0x80200000
restore ${DTB} binary 0x82200000

set $a0 = 0
set $a1 = 0x82200000
set $pc = 0x80000000
set $dpc = 0x80000000

printf "Starting Yocto OpenSBI fw_jump at 0x80000000\n"
printf "Bundled Linux Image loaded at 0x80200000, DTB at 0x82200000\n"
info registers pc a0 a1 mhartid mstatus misa

continue&
shell sleep 30

printf "Boot window elapsed; disconnecting while the target keeps running.\n"

disconnect
quit
