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

break mmu_done
break mmu_fail
continue

set $done = *(unsigned long long *)0x80302000
if $done != 0x4d4d554f4b212121
  printf "FAIL: S-mode MMU magic = 0x%016lx\n", $done
  x/8gx 0x80302000
  info registers pc a0 a1 scause sepc stval satp sstatus mhartid mstatus
  detach
  quit 1
end

printf "PASS: S-mode Sv39 MMU smoke reached high-VA code and wrote MMUOK magic\n"
printf "Check UART for: CVA6 ZCU111 S-mode Sv39 MMU smoke\n"
printf "Check UART for: S-mode Sv39 MMU smoke passed\n"
info registers pc a0 a1 scause sepc stval satp sstatus mhartid mstatus
x/8gx 0x80302000

detach
quit
