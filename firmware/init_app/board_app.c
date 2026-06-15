#include "rv32i_soc.h"

static const u8 hex_seg[16] = {
    0x40u, 0x79u, 0x24u, 0x30u,
    0x19u, 0x12u, 0x02u, 0x78u,
    0x00u, 0x10u, 0x08u, 0x03u,
    0x46u, 0x21u, 0x06u, 0x0eu,
};

static volatile u32 boot_mark = 0x12345678u;

static void delay(void)
{
    volatile u32 i;

    for (i = 0u; i < 200000u; i++) {
    }
}

static u32 make_hex_low(u32 value)
{
    u32 digit0;
    u32 digit1;
    u32 digit2;
    u32 digit3;

    digit0 = hex_seg[value & 0x0fu];
    digit1 = hex_seg[(value >> 4) & 0x0fu];
    digit2 = hex_seg[(value >> 8) & 0x0fu];
    digit3 = hex_seg[(value >> 12) & 0x0fu];

    return digit0 | (digit1 << 8) | (digit2 << 16) | (digit3 << 24);
}

static u32 make_hex_high(u32 value)
{
    u32 digit4;
    u32 digit5;

    digit4 = hex_seg[(value >> 16) & 0x0fu];
    digit5 = hex_seg[(value >> 20) & 0x0fu];

    return digit4 | (digit5 << 8);
}

static void show_hex24(u32 value)
{
    HEX_LOW = make_hex_low(value);
    HEX_HIGH = make_hex_high(value);
}

static void uart_put_hex8(u32 value)
{
    rv32i_uart_put_hex4(value >> 4);
    rv32i_uart_put_hex4(value);
}

static void send_key_event(u32 key, u32 count)
{
    rv32i_uart_putc('K');
    rv32i_uart_put_hex4(key);
    rv32i_uart_putc(' ');
    uart_put_hex8(count);
    rv32i_uart_putc('\n');
}

int main(void)
{
    u32 led;
    u32 blink;
    u32 last_key;
    u32 key_count;

    led = 1u;
    blink = 0u;
    key_count = 0u;
    last_key = rv32i_key_read() & 0x0fu;

    rv32i_led_write(led);
    show_hex24(boot_mark);
    rv32i_uart_puts("init app\n");

    while (1) {
        u32 sw;
        u32 key;

        delay();

        sw = rv32i_sw_read() & 0x03ffu;
        key = rv32i_key_read() & 0x0fu;

        if (key != last_key) {
            last_key = key;
            key_count++;
            led ^= 2u;
            send_key_event(key, key_count);
        }

        blink ^= 1u;
        if (blink != 0u) {
            led |= 0x200u;
        } else {
            led &= ~0x200u;
        }

        led = (led & 0x0203u) | ((sw & 0x007fu) << 2);
        rv32i_led_write(led);
        show_hex24((key_count << 16) | sw);
    }
}
