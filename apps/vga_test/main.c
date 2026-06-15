#include "rv32i_soc.h"

#define VGA_FB_WORDS (RV32I_VGA_FB_PIXELS / 4u)

static u8 make_color(u32 x, u32 y, u32 frame)
{
    u32 band;
    u32 stripe;

    band = x >> 5;
    if (band > 7u) {
        band = 7u;
    }
    stripe = (y + frame) >> 3;

    if (stripe & 1u) {
        band = 7u - band;
    }

    return (u8)((band << 5) | ((y & 0x1cu) << 1) | (x & 0x03u));
}

static void draw_frame(u32 frame)
{
    volatile u32 *fb;
    u32 x;
    u32 y;
    u32 out_index;

    fb = (volatile u32 *)RV32I_VGA_FB_BASE;
    out_index = 0u;

    for (y = 0u; y < RV32I_VGA_FB_HEIGHT; y++) {
        for (x = 0u; x < RV32I_VGA_FB_WIDTH; x += 4u) {
            u32 p0;
            u32 p1;
            u32 p2;
            u32 p3;

            p0 = make_color(x, y, frame);
            p1 = make_color(x + 1u, y, frame);
            p2 = make_color(x + 2u, y, frame);
            p3 = make_color(x + 3u, y, frame);

            fb[out_index] = p0 | (p1 << 8) | (p2 << 16) | (p3 << 24);
            out_index++;
        }
    }
}

static void delay(void)
{
    volatile u32 i;

    for (i = 0u; i < 60000u; i++) {
    }
}

int main(void)
{
    u32 frame;

    LEDR = 0x001u;
    rv32i_uart_puts("VGA test\n");

    frame = 0u;
    while (1) {
        draw_frame(frame);
        LEDR = 0x100u | (frame & 0x0ffu);
        frame++;
        delay();
    }
}
