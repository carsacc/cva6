set pagination off
set confirm off
set architecture riscv:rv64

file build/opensbi/platform/generic/firmware/fw_payload.elf
add-symbol-file build/payload.elf 0x80200000

target extended-remote localhost:3333
monitor halt
monitor riscv dmi_write 0x10 0x00000001

load
restore build/zcu111-cva6.dtb binary 0x82000000

set $a0 = 0
set $a1 = 0x82000000
set $pc = 0x80000000
set $dpc = 0x80000000

break payload_done
continue

set $done = *(unsigned long long *)0x80300000
if $done != 0x4f534249444f4e45
  printf "FAIL: OpenSBI payload magic = 0x%016lx\n", $done
  detach
  quit 1
end

printf "PASS: OpenSBI reached S-mode payload and wrote OSBIDONE magic\n"
printf "Check UART for OpenSBI banner and: CVA6 ZCU111 OpenSBI S-mode payload reached\n"
info registers pc a0 a1 mhartid mstatus misa
x/gx 0x80300000

detach
quit
