set pagination off
set confirm off
set architecture riscv:rv64

file build/coremark-baremetal.elf
target extended-remote localhost:3333
monitor halt
monitor riscv dmi_write 0x10 0x00000001

load
monitor halt
monitor riscv dmi_write 0x10 0x00000001
set $pc = 0x80000000
set $dpc = 0x80000000

break coremark_done_loop
continue

set $done = *(unsigned long long *)&coremark_done
if $done != 0x434d41524b444f4e
  printf "FAIL: coremark_done = 0x%016lx\n", $done
  detach
  quit 1
end

set $status = *(unsigned int *)&coremark_status
if $status != 0
  printf "FAIL: coremark_status = %u\n", $status
  detach
  quit 1
end

printf "PASS: CoreMark bare-metal program reached completion loop\n"
printf "Check the serial terminal for CoreMark output on /dev/ttyUSB2 at 115200 8N1\n"
info registers pc
x/gx &coremark_done
x/wx &coremark_status

detach
quit
