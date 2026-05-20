set pagination off
set confirm off
set architecture riscv:rv64
set remotetimeout 120
set target-async on

file ../test-05-opensbi-smoke/build/opensbi/platform/generic/firmware/fw_jump.elf

target extended-remote localhost:3333
monitor halt
# Start every boot attempt from a clean hart/debug-module state.
monitor riscv dmi_write 0x10 0x00000003
monitor sleep 10
monitor riscv dmi_write 0x10 0x80000001
monitor sleep 10
monitor halt
monitor riscv dmi_write 0x10 0x00000001

load
restore build/artifacts/Image binary 0x80200000
restore build/artifacts/zcu111-linux.dtb binary 0x82200000

set $a0 = 0
set $a1 = 0x82200000
set $pc = 0x80000000
set $dpc = 0x80000000

printf "Starting OpenSBI fw_jump at 0x80000000\n"
printf "BusyBox Linux Image loaded at 0x80200000, DTB loaded at 0x82200000\n"
printf "Watch UART for the BusyBox shell prompt.\n"
info registers pc a0 a1 mhartid mstatus misa

continue&
shell sleep 30

printf "Boot window elapsed; disconnecting while the target keeps running.\n"

disconnect
quit
