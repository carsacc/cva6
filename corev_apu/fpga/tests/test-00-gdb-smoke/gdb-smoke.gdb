set pagination off
set confirm off
set architecture riscv:rv64

target extended-remote localhost:3333
monitor halt
monitor riscv dmi_write 0x10 0x00000001

echo == Registers ==\n
info registers pc
info registers misa mhartid mstatus

echo == Disassembly before stepi ==\n
x/8i $pc

stepi

echo == Disassembly after stepi ==\n
info registers pc
x/4i $pc

detach
quit
