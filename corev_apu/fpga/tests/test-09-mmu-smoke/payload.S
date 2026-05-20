    .equ UART_BASE,        0x10000000
    .equ UART_RBR_THR_DLL, 0x00
    .equ UART_IER_DLM,     0x04
    .equ UART_FCR_IIR,     0x08
    .equ UART_LCR,         0x0c
    .equ UART_LSR,         0x14

    .equ PTE_V,            0x001
    .equ PTE_R,            0x002
    .equ PTE_W,            0x004
    .equ PTE_X,            0x008
    .equ PTE_A,            0x040
    .equ PTE_D,            0x080
    .equ PTE_RWXAD,        0x0cf

    .equ SATP_MODE_SV39,   0x8000000000000000
    .equ HIGH_ALIAS_MASK,  0xffffffff00000000

    .equ PTE_ROOT_UART,    0
    .equ PTE_ROOT_DDR,     2
    .equ PTE_ROOT_HIGH,    510

    .equ MMU_MAGIC_ADDR,   0x80302000
    .equ MMU_TEST_PA,      0x80302040
    .equ MMU_TEST_VA,      0xffffffff80302040
    .equ MMU_PASS_MAGIC,   0x4d4d554f4b212121
    .equ MMU_FAIL_MAGIC,   0x4d4d554641494c21
    .equ MMU_TEST_VALUE,   0x535633394f4b2121

    .section .text
    .globl _start
_start:
    la sp, payload_stack_top
    call uart_init
    la a0, start_msg
    call uart_puts

    la t0, trap_handler
    csrw stvec, t0

    la a0, root_pt
    call zero_page

    la t0, root_pt

    li t1, 0x00000000
    call make_l2_leaf
    sd a0, PTE_ROOT_UART * 8(t0)

    li t1, 0x80000000
    call make_l2_leaf
    sd a0, PTE_ROOT_DDR * 8(t0)

    li t1, 0x80000000
    call make_l2_leaf
    li t3, PTE_ROOT_HIGH * 8
    add t3, t0, t3
    sd a0, 0(t3)

    sfence.vma
    srli t1, t0, 12
    li t2, SATP_MODE_SV39
    or t1, t1, t2
    csrw satp, t1
    sfence.vma

    li t0, MMU_TEST_VA
    li t1, MMU_TEST_VALUE
    sd t1, 0(t0)
    fence rw, rw

    li t0, MMU_TEST_PA
    ld t2, 0(t0)
    bne t1, t2, mmu_fail

    la t0, high_exec_target
    li t1, HIGH_ALIAS_MASK
    or t0, t0, t1
    jr t0

make_l2_leaf:
    srli a0, t1, 12
    slli a0, a0, 10
    ori a0, a0, PTE_RWXAD
    ret

zero_page:
    mv t3, a0
    li t4, 512
1:
    sd zero, 0(t3)
    addi t3, t3, 8
    addi t4, t4, -1
    bnez t4, 1b
    ret

    .align 2
trap_handler:
    li t0, MMU_MAGIC_ADDR
    li t1, MMU_FAIL_MAGIC
    sd t1, 0(t0)
    csrr t1, scause
    sd t1, 8(t0)
    csrr t1, sepc
    sd t1, 16(t0)
    csrr t1, stval
    sd t1, 24(t0)
    csrr t1, satp
    sd t1, 32(t0)
    la a0, trap_fail_msg
    call uart_puts

mmu_fail:
    li t0, MMU_MAGIC_ADDR
    li t1, MMU_FAIL_MAGIC
    sd t1, 0(t0)
    la a0, fail_msg
    call uart_puts
1:
    wfi
    j 1b

    .align 2
high_exec_target:
    li t0, MMU_MAGIC_ADDR
    li t1, MMU_PASS_MAGIC
    sd t1, 0(t0)
    la a0, pass_msg
    call uart_puts

mmu_done:
    wfi
    j mmu_done

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
    .asciz "\r\nCVA6 ZCU111 S-mode Sv39 MMU smoke\r\n"
pass_msg:
    .asciz "S-mode Sv39 MMU smoke passed\r\n"
fail_msg:
    .asciz "FAIL: S-mode Sv39 MMU smoke failed\r\n"
trap_fail_msg:
    .asciz "FAIL: S-mode Sv39 MMU trap\r\n"

    .section .bss
    .align 12
root_pt:
    .space 4096
    .align 12
payload_stack:
    .space 4096
payload_stack_top:
