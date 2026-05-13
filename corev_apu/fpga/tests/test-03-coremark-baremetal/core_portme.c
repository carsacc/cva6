#include "coremark.h"

ee_u32 default_num_contexts = 1;

static CORETIMETYPE start_time_val;
static CORETIMETYPE stop_time_val;

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif

volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

extern void uart_init(void);
extern void uart_puts(const char *str);

static inline CORE_TICKS read_mcycle(void)
{
    CORE_TICKS cycles;
    __asm__ volatile ("csrr %0, mcycle" : "=r"(cycles));
    return cycles;
}

void portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)p;
    (void)argc;
    (void)argv;
    uart_init();
    uart_puts("\r\nCVA6 ZCU111 CoreMark bare-metal test\r\n");
}

void portable_fini(core_portable *p)
{
    (void)p;
    uart_puts("CoreMark bare-metal test finished\r\n");
}

void start_time(void)
{
    start_time_val = read_mcycle();
}

void stop_time(void)
{
    stop_time_val = read_mcycle();
}

CORE_TICKS get_time(void)
{
    return stop_time_val - start_time_val;
}

secs_ret time_in_secs(CORE_TICKS ticks)
{
    return (secs_ret)(ticks / CLOCK_HZ);
}

void *portable_malloc(ee_size_t size)
{
    (void)size;
    return 0;
}

void portable_free(void *p)
{
    (void)p;
}
