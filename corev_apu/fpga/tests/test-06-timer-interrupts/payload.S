    .equ UART_BASE,        0x10000000
    .equ UART_RBR_THR_DLL, 0x00
    .equ UART_IER_DLM,     0x04
    .equ UART_FCR_IIR,     0x08
    .equ UART_LCR,         0x0c
    .equ UART_LSR,         0x14

    .equ SBI_EXT_TIME,       0x54494d45
    .equ SBI_TIME_SET_TIMER, 0
    .equ TIMER_DELTA,        250000
    .equ TIMER_MAGIC_ADDR,   0x80301000
    .equ TIMER_PASS_MAGIC,   0x54494d45524f4b21
    .equ TIMER_FAIL_MAGIC,   0x54494d4552464149
    .equ SBI_FAIL_MAGIC,     0x5342494641494c21
    .equ TRAP_FAIL_MAGIC,    0x545241504641494c
    .equ SCAUSE_STIMER,      0x8000000000000005

    .section .text
    .globl _start
_start:
    la sp, payload_stack_top
    call uart_init
    la a0, start_msg
    call uart_puts

    la t0, trap_handler
    csrw stvec, t0

    csrr a0, time
    li t0, TIMER_DELTA
    add a0, a0, t0
    call sbi_set_timer
    bnez a0, sbi_fail

    li t0, 0x20
    csrs sie, t0
    csrsi sstatus, 0x2

timer_wait:
    wfi
    j timer_wait

sbi_set_timer:
    li a7, SBI_EXT_TIME
    li a6, SBI_TIME_SET_TIMER
    ecall
    ret

    .align 2
trap_handler:
    csrci sstatus, 0x2
    li t0, 0x20
    csrc sie, t0

    csrr t0, scause
    li t1, SCAUSE_STIMER
    bne t0, t1, trap_fail

    li t0, TIMER_MAGIC_ADDR
    li t1, TIMER_PASS_MAGIC
    sd t1, 0(t0)

    la a0, pass_msg
    call uart_puts

timer_done:
    wfi
    j timer_done

sbi_fail:
    li t0, TIMER_MAGIC_ADDR
    li t1, SBI_FAIL_MAGIC
    sd t1, 0(t0)
    sd a0, 8(t0)
    la a0, sbi_fail_msg
    call uart_puts
    j timer_fail

trap_fail:
    li t0, TIMER_MAGIC_ADDR
    li t1, TRAP_FAIL_MAGIC
    sd t1, 0(t0)
    csrr t1, scause
    sd t1, 8(t0)
    csrr t1, sepc
    sd t1, 16(t0)
    csrr t1, stval
    sd t1, 24(t0)
    la a0, trap_fail_msg
    call uart_puts

timer_fail:
    wfi
    j timer_fail

uart_init:
    li t0, UART_BASE + UART_IER_DLM
    sb zero, 0(t0)
    li t0, UART_BASE + UART_LCR
    li t1, 0x80
    sb t1, 0(t0)
    li t0, UART_BASE + UART_RBR_THR_DLL
    li t1, 27
    sb t1, 0(t0)
    li t0, UART_BASE + UART_IER_DLM
    sb zero, 0(t0)
    li t0, UART_BASE + UART_LCR
    li t1, 0x03
    sb t1, 0(t0)
    li t0, UART_BASE + UART_FCR_IIR
    li t1, 0x07
    sb t1, 0(t0)
    ret

uart_puts:
    mv t2, a0
1:
    lbu t3, 0(t2)
    beqz t3, 3f
2:
    li t0, UART_BASE + UART_LSR
    lbu t1, 0(t0)
    andi t1, t1, 0x20
    beqz t1, 2b
    li t0, UART_BASE + UART_RBR_THR_DLL
    sb t3, 0(t0)
    addi t2, t2, 1
    j 1b
3:
    ret

    .section .rodata
start_msg:
    .asciz "\r\nCVA6 ZCU111 S-mode timer interrupt test\r\n"
pass_msg:
    .asciz "S-mode timer interrupt fired\r\n"
sbi_fail_msg:
    .asciz "FAIL: sbi_set_timer returned an error\r\n"
trap_fail_msg:
    .asciz "FAIL: unexpected S-mode trap cause\r\n"

    .section .bss
    .align 12
payload_stack:
    .space 4096
payload_stack_top:
