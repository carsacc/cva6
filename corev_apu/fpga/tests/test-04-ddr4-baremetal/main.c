#include <stdint.h>

#ifndef DDR4_TEST_BYTES
#define DDR4_TEST_BYTES (16UL * 1024UL * 1024UL)
#endif

#ifndef DDR4_TEST_STRIDE_BYTES
#define DDR4_TEST_STRIDE_BYTES 64UL
#endif

#ifndef DDR4_CONTIG_BYTES
#define DDR4_CONTIG_BYTES (256UL * 1024UL)
#endif

#define DDR4_SWEEP_BASE  ((uintptr_t)0x80100000UL)
#define DDR4_CONTIG_BASE ((uintptr_t)0x81100000UL)
#define DDR4_BYTE_BASE   ((uintptr_t)0x81200000UL)

extern void uart_init(void);
extern void uart_puts(const char *str);
extern int printf(const char *fmt, ...);

volatile uintptr_t ddr4_fail_addr;
volatile uint64_t ddr4_expected;
volatile uint64_t ddr4_actual;
volatile uint32_t ddr4_fail_phase;
volatile uint32_t ddr4_checks;

static inline void fence_rw(void)
{
    __asm__ volatile ("fence rw, rw" ::: "memory");
}

static uint64_t pattern_for(uintptr_t addr, uint64_t salt)
{
    uint64_t x = ((uint64_t)addr) ^ salt;
    x ^= x >> 33;
    x *= 0xff51afd7ed558ccdUL;
    x ^= x >> 33;
    x *= 0xc4ceb9fe1a85ec53UL;
    x ^= x >> 33;
    return x;
}

static int fail(uint32_t phase, uintptr_t addr, uint64_t expected, uint64_t actual)
{
    ddr4_fail_phase = phase;
    ddr4_fail_addr = addr;
    ddr4_expected = expected;
    ddr4_actual = actual;

    printf("FAIL phase %u addr 0x%016lx expected 0x%016lx actual 0x%016lx\r\n",
           phase,
           (unsigned long)addr,
           (unsigned long)expected,
           (unsigned long)actual);
    return 1;
}

static int sweep_test(void)
{
    const uintptr_t base = DDR4_SWEEP_BASE;
    const uintptr_t end = DDR4_SWEEP_BASE + DDR4_TEST_BYTES;
    uintptr_t step = DDR4_TEST_STRIDE_BYTES < 8 ? 8 : DDR4_TEST_STRIDE_BYTES;
    uintptr_t addr;

    step &= ~(uintptr_t)7;

    printf("Sweep write/read: base 0x%016lx bytes %lu stride %lu\r\n",
           (unsigned long)base,
           (unsigned long)DDR4_TEST_BYTES,
           (unsigned long)step);

    for (addr = base; addr < end; addr += step) {
        *(volatile uint64_t *)addr = pattern_for(addr, 0x1111222233334444UL);
        ddr4_checks++;
    }
    fence_rw();

    for (addr = base; addr < end; addr += step) {
        uint64_t expected = pattern_for(addr, 0x1111222233334444UL);
        uint64_t actual = *(volatile uint64_t *)addr;
        ddr4_checks++;
        if (actual != expected)
            return fail(1, addr, expected, actual);
    }

    for (addr = base; addr < end; addr += step) {
        *(volatile uint64_t *)addr = pattern_for(addr, 0xaaaabbbbccccddddUL);
        ddr4_checks++;
    }
    fence_rw();

    for (addr = base; addr < end; addr += step) {
        uint64_t expected = pattern_for(addr, 0xaaaabbbbccccddddUL);
        uint64_t actual = *(volatile uint64_t *)addr;
        ddr4_checks++;
        if (actual != expected)
            return fail(2, addr, expected, actual);
    }

    return 0;
}

static int contiguous_test(void)
{
    uintptr_t addr;
    const uintptr_t base = DDR4_CONTIG_BASE;
    const uintptr_t end = DDR4_CONTIG_BASE + DDR4_CONTIG_BYTES;

    printf("Contiguous 64-bit window: base 0x%016lx bytes %lu\r\n",
           (unsigned long)base,
           (unsigned long)DDR4_CONTIG_BYTES);

    for (addr = base; addr < end; addr += 8) {
        *(volatile uint64_t *)addr = pattern_for(addr, 0x0123456789abcdefUL);
        ddr4_checks++;
    }
    fence_rw();

    for (addr = base; addr < end; addr += 8) {
        uint64_t expected = pattern_for(addr, 0x0123456789abcdefUL);
        uint64_t actual = *(volatile uint64_t *)addr;
        ddr4_checks++;
        if (actual != expected)
            return fail(3, addr, expected, actual);
    }

    return 0;
}

static int byte_lane_test(void)
{
    uintptr_t addr;
    const uintptr_t base = DDR4_BYTE_BASE;
    const uintptr_t bytes = 256;

    printf("Byte-lane window: base 0x%016lx bytes %lu\r\n",
           (unsigned long)base,
           (unsigned long)bytes);

    for (addr = base; addr < base + bytes; addr += 8)
        *(volatile uint64_t *)addr = 0;
    fence_rw();

    for (addr = base; addr < base + bytes; addr++) {
        uint8_t value = (uint8_t)((addr ^ (addr >> 8) ^ 0x5aU) & 0xffU);
        *(volatile uint8_t *)addr = value;
        ddr4_checks++;
    }
    fence_rw();

    for (addr = base; addr < base + bytes; addr++) {
        uint8_t expected = (uint8_t)((addr ^ (addr >> 8) ^ 0x5aU) & 0xffU);
        uint8_t actual = *(volatile uint8_t *)addr;
        ddr4_checks++;
        if (actual != expected)
            return fail(4, addr, expected, actual);
    }

    return 0;
}

int main(void)
{
    uart_init();
    uart_puts("\r\nCVA6 ZCU111 DDR4 bare-metal memory test\r\n");
    printf("Program executes from 0x80000000; test starts at 0x%016lx\r\n",
           (unsigned long)DDR4_SWEEP_BASE);

    if (sweep_test() != 0)
        return 1;
    if (contiguous_test() != 0)
        return 1;
    if (byte_lane_test() != 0)
        return 1;

    printf("PASS: DDR4 memory test completed, checks %u\r\n", ddr4_checks);
    return 0;
}
