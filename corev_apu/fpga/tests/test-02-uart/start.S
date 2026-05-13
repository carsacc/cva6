    .equ UART_BASE, 0x10000000
    .equ UART_THR,  UART_BASE + 0
    .equ UART_IER,  UART_BASE + 4
    .equ UART_FCR,  UART_BASE + 8
    .equ UART_LCR,  UART_BASE + 12
    .equ UART_MCR,  UART_BASE + 16
    .equ UART_LSR,  UART_BASE + 20
    .equ UART_DLL,  UART_BASE + 0
    .equ UART_DLM,  UART_BASE + 4

    .section .text.init, "ax"
    .globl _start
_start:
    la   sp, _stack_top

    /* 50 MHz input clock, 115200 baud: divisor = 50e6 / (115200 * 16) = 27. */
    li   t0, UART_IER
    sb   zero, 0(t0)

    li   t0, UART_LCR
    li   t1, 0x80
    sb   t1, 0(t0)

    li   t0, UART_DLL
    li   t1, 27
    sb   t1, 0(t0)

    li   t0, UART_DLM
    sb   zero, 0(t0)

    li   t0, UART_LCR
    li   t1, 0x03
    sb   t1, 0(t0)

    li   t0, UART_FCR
    li   t1, 0x07
    sb   t1, 0(t0)

    li   t0, UART_MCR
    sb   zero, 0(t0)

    la   s0, message

1:
    lbu  a0, 0(s0)
    beqz a0, 4f
2:
    li   t0, UART_LSR
    lbu  t1, 0(t0)
    andi t1, t1, 0x20
    beqz t1, 2b
    li   t0, UART_THR
    sb   a0, 0(t0)
    addi s0, s0, 1
    j    1b

4:
    la   t0, uart_done
    li   t1, 0x5552415254504153
    sd   t1, 0(t0)
    .globl uart_done_loop
uart_done_loop:
5:
    j    5b

    .section .rodata, "a"
message:
    .asciz "CVA6 ZCU111 UART bare-metal test\r\n"

    .section .data, "aw"
    .globl uart_done
uart_done:
    .quad 0
