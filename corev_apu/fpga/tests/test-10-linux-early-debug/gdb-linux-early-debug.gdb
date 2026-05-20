set pagination off
set confirm off
set architecture riscv:rv64
set remotetimeout 120
set target-async on

file ../test-05-opensbi-smoke/build/opensbi/platform/generic/firmware/fw_jump.elf

target extended-remote localhost:3333
monitor halt
monitor riscv dmi_write 0x10 0x00000003
monitor sleep 10
monitor riscv dmi_write 0x10 0x80000001
monitor sleep 10
monitor halt
monitor riscv dmi_write 0x10 0x00000001

load
restore ../test-07-linux-build/build/artifacts/Image binary 0x80200000
restore ../test-07-linux-build/build/artifacts/zcu111-linux.dtb binary 0x82200000

symbol-file ../test-07-linux-build/build/artifacts/vmlinux

set $a0 = 0
set $a1 = 0x82200000
set $pc = 0x80000000
set $dpc = 0x80000000

printf "Linux early debug loaded:\n"
printf "  OpenSBI fw_jump: 0x80000000\n"
printf "  Linux Image:     0x80200000\n"
printf "  Linux DTB:       0x82200000\n"
info registers pc a0 a1 mhartid mstatus misa

break *0x802000d4
commands
  silent
  printf "\n== hit _start_kernel (physical 0x802000d4) ==\n"
  info registers pc a0 a1 scause sepc stval satp sstatus
  continue
end

break *0x80436264
commands
  silent
  printf "\n== hit setup_vm (physical 0x80436264) ==\n"
  info registers pc a0 a1 ra sp scause sepc stval satp sstatus
  x/6gx 0x80537690
  continue
end

break *0x80200040
commands
  silent
  printf "\n== hit relocate_enable_mmu (physical 0x80200040) ==\n"
  info registers pc a0 a1 a2 ra sp scause sepc stval satp sstatus
  x/8gx 0x80537690
  x/8gx 0x80454000
  x/8gx 0x8064d000
  continue
end

break *0x80200090
commands
  silent
  printf "\n== before trampoline satp write (physical 0x80200090) ==\n"
  info registers pc a0 a1 a2 ra sp scause sepc stval satp sstatus stvec
  x/16gx 0x8064d000
  continue
end

break *0x8000ad74
commands
  silent
  printf "\nFAIL: reached OpenSBI trap/hang loop at 0x8000ad74\n"
  info registers pc a0 a1 scause sepc stval satp sstatus stvec mcause mepc mtval mstatus
  x/8gx 0x80537690
  x/16gx 0x8064d000
  detach
  quit 1
end

break *0x80421e8c
break *0x80202910

printf "\nContinuing until Linux panic/restart or OpenSBI trap hang.\n"
continue

printf "\n== final state after Linux early-debug stop ==\n"
info registers pc ra sp a0 a1 a2 a3 a4 a5 a6 a7
info registers scause sepc stval satp sstatus stvec mcause mepc mtval mstatus
x/s $a0
x/12i $pc
detach
quit
