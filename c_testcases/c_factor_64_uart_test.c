#define UART_BASE   0x20000000u
#define UART_TXDATA (*(volatile unsigned int *)(UART_BASE + 0u))
#define UART_STATUS (*(volatile unsigned int *)(UART_BASE + 4u))

#define MAX_FACTORS 16
unsigned long long factors[MAX_FACTORS];

static void uart_putc(unsigned int c)
{
    while ((UART_STATUS & 1u) == 0u) {
    }

    UART_TXDATA = c;
}

static void uart_newline(void)
{
    uart_putc('\r');
    uart_putc('\n');
}

static void uart_hex_digit(unsigned int value)
{
    value = value & 15u;

    if (value < 10u) {
        uart_putc(value + '0');
    } else {
        uart_putc(value + ('A' - 10u));
    }
}

static void uart_hex32(unsigned int value)
{
    for (int shift = 28; shift >= 0; shift = shift - 4) {
        uart_hex_digit(value >> shift);
    }
}

static void uart_hex64(unsigned long long value)
{
    uart_hex32((unsigned int)(value >> 32));
    uart_hex32((unsigned int)value);
}

static void uart_print_u64(char prefix, unsigned int index, unsigned long long value)
{
    uart_putc((unsigned int)prefix);
    uart_hex_digit(index);
    uart_putc('=');
    uart_hex64(value);
    uart_newline();
}

static void record_factor(unsigned long long factor, unsigned int index)
{
    if (index < MAX_FACTORS) {
        factors[index] = factor;
    }
    uart_print_u64('F', index, factor);
}

int main(void)
{
    unsigned long long n = 269992950011;
    unsigned long long divisor_squared;

    unsigned int index = 0;
    uart_print_u64('N', 0u, n);

    while ((n % 2) == 0) {
        record_factor(2, index);
        n = n / 2;
        index = index + 1;
    }

    divisor_squared = 9;
    for (unsigned int divisor = 3; divisor_squared <= n; divisor = divisor + 2u) {
        while ((n % divisor) == 0) {
            record_factor(divisor, index);
            n = n / divisor;
            index = index + 1;
        }
        divisor_squared = divisor * divisor;
    }

    if (n > 1) {
        record_factor(n, index);
    }

    while (1) {
    }
}
