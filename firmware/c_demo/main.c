#include "rv32i_soc.h"

static void send_banner(void)
{
    rv32i_uart_puts("C demo\n");
}

int main(void)
{
    u32 last_key;

    rv32i_led_write(1u);
    send_banner();

    last_key = rv32i_key_read() & 0x0fu;

    while (1) {
        u32 key = rv32i_key_read() & 0x0fu;
        if (key != last_key) {
            last_key = key;
            rv32i_led_write(3u);
            rv32i_uart_putc('K');
            rv32i_uart_put_hex4(key);
            rv32i_uart_putc('\n');
        }
    }
}
