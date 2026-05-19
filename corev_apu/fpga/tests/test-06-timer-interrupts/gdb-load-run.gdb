set pagination off
set confirm off
set architecture riscv:rv64

file build/opensbi/platform/generic/firmware/fw_payload.elf
add-symbol-file build/payload.elf 0x80200000

target extended-remote localhost:3333
monitor halt
monitor riscv dmi_write 0x10 0x00000003
monitor sleep 10
monitor riscv dmi_write 0x10 0x80000001
monitor sleep 10
monitor halt
monitor riscv dmi_write 0x10 0x00000001

load
restore build/zcu111-cva6.dtb binary 0x82000000

set $a0 = 0
set $a1 = 0x82000000
set $pc = 0x80000000
set $dpc = 0x80000000

break timer_done
break timer_fail
continue

set $done = *(unsigned long long *)0x80301000
if $done != 0x54494d45524f4b21
  printf "FAIL: S-mode timer magic = 0x%016lx\n", $done
  x/4gx 0x80301000
  detach
  quit 1
end

printf "PASS: S-mode timer interrupt fired and wrote TIMEROK magic\n"
printf "Check UART for: CVA6 ZCU111 S-mode timer interrupt test\n"
printf "Check UART for: S-mode timer interrupt fired\n"
info registers pc a0 a1 scause sstatus sie sip mhartid mstatus
x/gx 0x80301000

detach
quit
