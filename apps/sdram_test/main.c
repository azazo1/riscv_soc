#include "rv32i_soc.h"

#define SDRAM_TEST_COUNT 6u
#define SDRAM_BYTE_TEST_ADDR (RV32I_SDRAM_BASE + 0x40u)

static const u8 hex_seg[16] = {
    0x40u, 0x79u, 0x24u, 0x30u,
    0x19u, 0x12u, 0x02u, 0x78u,
    0x00u, 0x10u, 0x08u, 0x03u,
    0x46u, 0x21u, 0x06u, 0x0eu,
};

static const u32 test_index[SDRAM_TEST_COUNT] = {
    0x00000000u,
    0x00000001u,
    0x00000100u,
    0x000003ffu,
    0x000007fdu,
    0x00ffffefu,
};

static const u32 test_pattern[SDRAM_TEST_COUNT] = {
    0x11223344u,
    0xa5a55a5au,
    0x55aa33ccu,
    0x01020304u,
    0xf0e1d2c3u,
    0x89abcdefu,
};

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

static void uart_put_hex32(u32 value)
{
    rv32i_uart_put_hex4(value >> 28);
    rv32i_uart_put_hex4(value >> 24);
    rv32i_uart_put_hex4(value >> 20);
    rv32i_uart_put_hex4(value >> 16);
    rv32i_uart_put_hex4(value >> 12);
    rv32i_uart_put_hex4(value >> 8);
    rv32i_uart_put_hex4(value >> 4);
    rv32i_uart_put_hex4(value);
}

static void fail(u32 step, u32 index, u32 expected, u32 actual)
{
    LEDR = 0x200u | (step & 0x00ffu);
    show_hex24(step);

    rv32i_uart_puts("SDRAM FAIL ");
    uart_put_hex32(step);
    rv32i_uart_putc(' ');
    uart_put_hex32(index);
    rv32i_uart_putc(' ');
    uart_put_hex32(expected);
    rv32i_uart_putc(' ');
    uart_put_hex32(actual);
    rv32i_uart_putc('\n');

    while (1) {
        delay();
        LEDR ^= 0x200u;
    }
}

static void check_word(u32 step, u32 index, u32 value)
{
    volatile u32 *sdram;
    u32 actual;

    sdram = (volatile u32 *)RV32I_SDRAM_BASE;
    sdram[index] = value;
    actual = sdram[index];

    if (actual != value) {
        fail(step, index, value, actual);
    }
}

static void check_all_words(u32 step_base)
{
    u32 i;

    for (i = 0u; i < SDRAM_TEST_COUNT; i++) {
        check_word(step_base + i, test_index[i], test_pattern[i]);
    }

    for (i = 0u; i < SDRAM_TEST_COUNT; i++) {
        check_word(step_base + 0x10u + i, test_index[i], ~test_pattern[i]);
    }
}

static void check_byte_lanes(void)
{
    volatile u32 *word;
    volatile u8 *byte;
    u32 actual;

    word = (volatile u32 *)SDRAM_BYTE_TEST_ADDR;
    byte = (volatile u8 *)SDRAM_BYTE_TEST_ADDR;

    *word = 0x11223344u;
    byte[0] = 0xaau;
    byte[1] = 0xbbu;
    byte[2] = 0xccu;
    byte[3] = 0xddu;

    actual = *word;
    if (actual != 0xddccbbaau) {
        fail(0x80u, 0x00000010u, 0xddccbbaau, actual);
    }
}

int main(void)
{
    LEDR = 0x001u;
    show_hex24(0u);
    rv32i_uart_puts("SDRAM test\n");

    LEDR = 0x002u;
    check_all_words(0x10u);
    show_hex24(0x111111u);

    LEDR = 0x004u;
    check_byte_lanes();
    show_hex24(0x222222u);

    LEDR = 0x3ffu;
    rv32i_uart_puts("SDRAM PASS\n");

    while (1) {
    }
}
