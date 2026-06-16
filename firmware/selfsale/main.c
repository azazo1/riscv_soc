#include "rv32i_soc.h"

#ifndef SELFSALE_DELAY_TICKS
#define SELFSALE_DELAY_TICKS 50000u
#endif

#define KEY_SELECT 0x1u
#define KEY_COIN_1 0x2u
#define KEY_COIN_5 0x4u
#define KEY_COIN_10 0x8u

#define STATUS_IDLE 0u
#define STATUS_COIN 1u
#define STATUS_DONE 2u
#define STATUS_REFUND 3u

static u32 seg_digit(u32 value)
{
    value = value & 0x0fu;

    if (value == 0u) return 0x40u;
    if (value == 1u) return 0x79u;
    if (value == 2u) return 0x24u;
    if (value == 3u) return 0x30u;
    if (value == 4u) return 0x19u;
    if (value == 5u) return 0x12u;
    if (value == 6u) return 0x02u;
    if (value == 7u) return 0x78u;
    if (value == 8u) return 0x00u;
    if (value == 9u) return 0x10u;
    if (value == 10u) return 0x08u;
    if (value == 11u) return 0x03u;
    if (value == 12u) return 0x46u;
    if (value == 13u) return 0x21u;
    if (value == 14u) return 0x06u;
    return 0x0eu;
}

static void split_decimal(u32 value, u32 *tens, u32 *ones)
{
    u32 high = 0u;

    if (value >= 90u) {
        high = 9u;
        value = value - 90u;
    } else if (value >= 80u) {
        high = 8u;
        value = value - 80u;
    } else if (value >= 70u) {
        high = 7u;
        value = value - 70u;
    } else if (value >= 60u) {
        high = 6u;
        value = value - 60u;
    } else if (value >= 50u) {
        high = 5u;
        value = value - 50u;
    } else if (value >= 40u) {
        high = 4u;
        value = value - 40u;
    } else if (value >= 30u) {
        high = 3u;
        value = value - 30u;
    } else if (value >= 20u) {
        high = 2u;
        value = value - 20u;
    } else if (value >= 10u) {
        high = 1u;
        value = value - 10u;
    }

    *tens = high;
    *ones = value;
}

static void write_hex_pair(u32 amount, u32 price, u32 status)
{
    u32 amount_tens;
    u32 amount_ones;
    u32 price_tens;
    u32 price_ones;
    u32 hex_low;
    u32 hex_high;

    if (amount > 99u) amount = 99u;
    if (price > 99u) price = 99u;

    split_decimal(amount, &amount_tens, &amount_ones);
    split_decimal(price, &price_tens, &price_ones);

    /* HEX0/1 显示投入金额或找零, HEX2/3 显示商品价格。 */
    hex_low = seg_digit(amount_ones);
    hex_low = hex_low | (seg_digit(amount_tens) << 8);
    hex_low = hex_low | (seg_digit(price_ones) << 16);
    hex_low = hex_low | (seg_digit(price_tens) << 24);

    /* HEX4 显示订单状态, HEX5 固定显示 0。 */
    hex_high = seg_digit(status);
    hex_high = hex_high | (seg_digit(0u) << 8);

    HEX_LOW = hex_low;
    HEX_HIGH = hex_high;
}

static void delay_once(void)
{
    volatile u32 count = 0u;

    while (count < SELFSALE_DELAY_TICKS) {
        count = count + 1u;
    }
}

static u32 selected_price(u32 selected)
{
    if (selected == 1u) return 9u;   /* A: 0.9 元, 单位是角。 */
    if (selected == 2u) return 12u;  /* B: 1.2 元, 单位是角。 */
    if (selected == 3u) return 23u;  /* C: 2.3 元, 单位是角。 */
    return 0u;
}

static u32 selected_led(u32 selected)
{
    if (selected == 1u) return 0x001u;
    if (selected == 2u) return 0x002u;
    if (selected == 3u) return 0x004u;
    return 0x000u;
}

int main(void)
{
    u32 selected = 0u;
    u32 price = 0u;
    u32 coin_total = 0u;
    u32 display_amount = 0u;
    u32 status = STATUS_IDLE;
    u32 last_key = KEY & 0x0fu;

    while (1) {
        u32 sw = SW;
        u32 key;
        u32 pressed;

        if ((sw & 1u) == 0u) {
            selected = 0u;
            price = 0u;
            coin_total = 0u;
            display_amount = 0u;
            status = STATUS_IDLE;
            last_key = KEY & 0x0fu;

            LEDR = 0u;
            write_hex_pair(0u, 0u, STATUS_IDLE);
            delay_once();
            continue;
        }

        key = KEY & 0x0fu;
        pressed = last_key & (~key);
        last_key = key;

        if ((pressed & KEY_SELECT) != 0u) {
            if (selected == 0u) {
                selected = 1u;
                status = STATUS_IDLE;
                coin_total = 0u;
                display_amount = 0u;
            } else if (status == STATUS_COIN) {
                selected = 0u;
                status = STATUS_REFUND;
                display_amount = coin_total;
                coin_total = 0u;
            } else {
                selected = selected + 1u;
                if (selected > 3u) selected = 1u;
                status = STATUS_IDLE;
                coin_total = 0u;
                display_amount = 0u;
            }

            price = selected_price(selected);
        }

        if (selected != 0u) {
            u32 coin = 0u;

            if ((pressed & KEY_COIN_1) != 0u) coin = 1u;
            if ((pressed & KEY_COIN_5) != 0u) coin = 5u;
            if ((pressed & KEY_COIN_10) != 0u) coin = 10u;

            if (coin != 0u) {
                coin_total = coin_total + coin;

                if (coin_total >= price) {
                    display_amount = coin_total - price;
                    coin_total = 0u;
                    selected = 0u;
                    price = 0u;
                    status = STATUS_DONE;
                } else {
                    display_amount = coin_total;
                    status = STATUS_COIN;
                }
            }
        }

        /* LEDR[0..2] 指示 A/B/C, LEDR[9] 表示程序正在工作。 */
        LEDR = selected_led(selected) | 0x200u;
        write_hex_pair(display_amount, price, status);
        delay_once();
    }
}
