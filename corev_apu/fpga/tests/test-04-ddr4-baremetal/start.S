    .section .text.init, "ax"
    .globl _start
_start:
    la   sp, _stack_top

    la   t0, __bss_start
    la   t1, __bss_end
1:
    bgeu t0, t1, 2f
    sd   zero, 0(t0)
    addi t0, t0, 8
    j    1b
2:
    call main

    la   t0, ddr4_status
    sw   a0, 0(t0)

    la   t0, ddr4_done
    li   t1, 0x44445234444f4e45
    sd   t1, 0(t0)

    .globl ddr4_done_loop
ddr4_done_loop:
3:
    j    3b

    .section .data, "aw"
    .balign 8
    .globl ddr4_status
ddr4_status:
    .word 0xffffffff
    .word 0

    .balign 8
    .globl ddr4_done
ddr4_done:
    .quad 0
