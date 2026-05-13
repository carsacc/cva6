#include <stdarg.h>
#include <stdint.h>

#define UART_BASE 0x10000000UL
#define UART_THR  (UART_BASE + 0)
#define UART_IER  (UART_BASE + 4)
#define UART_FCR  (UART_BASE + 8)
#define UART_LCR  (UART_BASE + 12)
#define UART_MCR  (UART_BASE + 16)
#define UART_LSR  (UART_BASE + 20)
#define UART_DLL  (UART_BASE + 0)
#define UART_DLM  (UART_BASE + 4)

static void write_reg_u8(uintptr_t addr, uint8_t value)
{
    *(volatile uint8_t *)addr = value;
}

static uint8_t read_reg_u8(uintptr_t addr)
{
    return *(volatile uint8_t *)addr;
}

void uart_init(void)
{
    write_reg_u8(UART_IER, 0x00);
    write_reg_u8(UART_LCR, 0x80);
    write_reg_u8(UART_DLL, 27);
    write_reg_u8(UART_DLM, 0x00);
    write_reg_u8(UART_LCR, 0x03);
    write_reg_u8(UART_FCR, 0x07);
    write_reg_u8(UART_MCR, 0x00);
}

static void uart_putc(char c)
{
    if (c == '\n')
        uart_putc('\r');

    while ((read_reg_u8(UART_LSR) & 0x20) == 0) {
    }
    write_reg_u8(UART_THR, (uint8_t)c);
}

void uart_puts(const char *str)
{
    while (*str != '\0') {
        uart_putc(*str);
        str++;
    }
}

static int print_padding(int count, char pad)
{
    int written = 0;
    while (count-- > 0) {
        uart_putc(pad);
        written++;
    }
    return written;
}

static int print_unsigned(unsigned long value, unsigned int base, int width, char pad)
{
    char buf[32];
    int pos = 0;
    int written = 0;

    do {
        unsigned long digit = value % base;
        buf[pos++] = (digit < 10) ? (char)('0' + digit) : (char)('a' + digit - 10);
        value /= base;
    } while (value != 0);

    written += print_padding(width - pos, pad);
    while (pos-- > 0) {
        uart_putc(buf[pos]);
        written++;
    }

    return written;
}

static int print_signed(long value, int width, char pad)
{
    int written = 0;

    if (value < 0) {
        uart_putc('-');
        written++;
        value = -value;
    }

    return written + print_unsigned((unsigned long)value, 10, width, pad);
}

int printf(const char *fmt, ...)
{
    va_list ap;
    int written = 0;

    va_start(ap, fmt);
    while (*fmt != '\0') {
        int width = 0;
        char pad = ' ';
        int is_long = 0;

        if (*fmt != '%') {
            uart_putc(*fmt++);
            written++;
            continue;
        }

        fmt++;
        if (*fmt == '%') {
            uart_putc(*fmt++);
            written++;
            continue;
        }

        if (*fmt == '0') {
            pad = '0';
            fmt++;
        }
        while ((*fmt >= '0') && (*fmt <= '9')) {
            width = (width * 10) + (*fmt - '0');
            fmt++;
        }
        if (*fmt == 'l') {
            is_long = 1;
            fmt++;
        }

        switch (*fmt) {
        case 'd':
        case 'i':
            written += is_long ? print_signed(va_arg(ap, long), width, pad)
                               : print_signed(va_arg(ap, int), width, pad);
            break;
        case 'u':
            written += is_long ? print_unsigned(va_arg(ap, unsigned long), 10, width, pad)
                               : print_unsigned(va_arg(ap, unsigned int), 10, width, pad);
            break;
        case 'x':
        case 'X':
            written += is_long ? print_unsigned(va_arg(ap, unsigned long), 16, width, pad)
                               : print_unsigned(va_arg(ap, unsigned int), 16, width, pad);
            break;
        case 's': {
            const char *str = va_arg(ap, const char *);
            if (str == 0)
                str = "(null)";
            uart_puts(str);
            while (*str++ != '\0')
                written++;
            break;
        }
        case 'c':
            uart_putc((char)va_arg(ap, int));
            written++;
            break;
        default:
            uart_putc('%');
            uart_putc(*fmt);
            written += 2;
            break;
        }
        fmt++;
    }
    va_end(ap);

    return written;
}
