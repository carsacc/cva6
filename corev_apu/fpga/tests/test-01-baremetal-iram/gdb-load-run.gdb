set pagination off
set confirm off
set architecture riscv:rv64

file build/iram-smoke.elf
target extended-remote localhost:3333
monitor halt
monitor riscv dmi_write 0x10 0x00000001

load
monitor halt
monitor riscv dmi_write 0x10 0x00000001
set $pc = 0x80000000
set $dpc = 0x80000000

echo == Entry point before stepi ==\n
info registers pc
info registers dpc
x/8i $pc

break test_done
continue
echo == State after run window ==\n
info registers pc
x/8i $pc

set $magic0 = *(unsigned long long *)&test_result
set $magic1 = *((unsigned long long *)&test_result + 1)

if $magic0 != 0x435641365a435531
  printf "FAIL: test_result[0] = 0x%016lx\n", $magic0
  detach
  quit 1
end

if $magic1 != 0x600dca5e600dca5e
  printf "FAIL: test_result[1] = 0x%016lx\n", $magic1
  detach
  quit 1
end

printf "PASS: bare-metal IRAM smoke wrote expected magic values\n"
info registers pc
x/4i $pc
x/4gx &test_result

detach
quit
