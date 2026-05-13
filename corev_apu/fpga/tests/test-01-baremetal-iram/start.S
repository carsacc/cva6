    .section .text.init, "ax"
    .globl _start
_start:
    la   sp, _stack_top

    la   t0, test_result
    li   t1, 0x435641365a435531
    sd   t1, 0(t0)

    li   t1, 0x600dca5e600dca5e
    sd   t1, 8(t0)

    .globl test_done
test_done:
1:
    j    1b

    .section .data, "aw"
    .globl test_result
test_result:
    .quad 0
    .quad 0
