    .section .text
    .globl _start
_start:
    la sp, payload_stack_top
    call uart_init
    la a0, payload_msg
    call uart_puts

    li t0, 0x80300000
    li t1, 0x4f534249444f4e45
    sd t1, 0(t0)

payload_done:
    wfi
    j payload_done

uart_init:
    li t0, 0x10000004
    sb zero, 0(t0)
    li t0, 0x1000000c
    li t1, 0x80
    sb t1, 0(t0)
    li t0, 0x10000000
    li t1, 27
    sb t1, 0(t0)
    li t0, 0x10000004
    sb zero, 0(t0)
    li t0, 0x1000000c
    li t1, 0x03
    sb t1, 0(t0)
    li t0, 0x10000008
    li t1, 0x07
    sb t1, 0(t0)
    ret

uart_puts:
    mv t2, a0
1:
    lbu t3, 0(t2)
    beqz t3, 3f
2:
    li t0, 0x10000014
    lbu t1, 0(t0)
    andi t1, t1, 0x20
    beqz t1, 2b
    li t0, 0x10000000
    sb t3, 0(t0)
    addi t2, t2, 1
    j 1b
3:
    ret

    .section .rodata
payload_msg:
    .asciz "\r\nCVA6 ZCU111 OpenSBI S-mode payload reached\r\n"

    .section .bss
    .align 12
payload_stack:
    .space 4096
payload_stack_top:
