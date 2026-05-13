set pagination off
set confirm off
set architecture riscv:rv64

file build/uart-hello.elf
target extended-remote localhost:3333
monitor halt
monitor riscv dmi_write 0x10 0x00000001

load
monitor halt
monitor riscv dmi_write 0x10 0x00000001
set $pc = 0x80000000
set $dpc = 0x80000000

break uart_done_loop
continue

set $done = *(unsigned long long *)&uart_done
if $done != 0x5552415254504153
  printf "FAIL: uart_done = 0x%016lx\n", $done
  detach
  quit 1
end

printf "PASS: UART program reached ebreak after writing message\n"
printf "Check the serial terminal for: CVA6 ZCU111 UART bare-metal test\n"
info registers pc
x/gx &uart_done

detach
quit
