set pagination off
set confirm off
set architecture riscv:rv64

file build/ddr4-baremetal.elf
target extended-remote localhost:3333
monitor halt
monitor riscv dmi_write 0x10 0x00000001

load
monitor halt
monitor riscv dmi_write 0x10 0x00000001
set $pc = 0x80000000
set $dpc = 0x80000000

break ddr4_done_loop
continue

set $done = *(unsigned long long *)&ddr4_done
if $done != 0x44445234444f4e45
  printf "FAIL: ddr4_done = 0x%016lx\n", $done
  detach
  quit 1
end

set $status = *(unsigned int *)&ddr4_status
if $status != 0
  printf "FAIL: ddr4_status = %u\n", $status
  printf "fail_phase = %u\n", ddr4_fail_phase
  printf "fail_addr = 0x%016lx\n", ddr4_fail_addr
  printf "expected = 0x%016lx\n", ddr4_expected
  printf "actual   = 0x%016lx\n", ddr4_actual
  detach
  quit 1
end

printf "PASS: DDR4 bare-metal memory test reached completion loop\n"
printf "Check the serial terminal for DDR4 test output on /dev/ttyUSB2 at 115200 8N1\n"
info registers pc
x/gx &ddr4_done
x/wx &ddr4_status
p/x ddr4_checks

detach
quit
