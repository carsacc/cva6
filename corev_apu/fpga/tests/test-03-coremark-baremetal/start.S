    .section .text.init, "ax"
    .globl _start
_start:
    la   sp, _stack_top
    call main

    la   t0, coremark_status
    sw   a0, 0(t0)

    la   t0, coremark_done
    li   t1, 0x434d41524b444f4e
    sd   t1, 0(t0)

    .globl coremark_done_loop
coremark_done_loop:
1:
    j    1b

    .section .data, "aw"
    .balign 8
    .globl coremark_status
coremark_status:
    .word 0xffffffff
    .word 0

    .balign 8
    .globl coremark_done
coremark_done:
    .quad 0
