#include "rv32i_soc.h"

static volatile float a_value = 1.5f;
static volatile float b_value = 2.25f;
static volatile int out_value;

int main(void)
{
    float sum;
    float product;
    int out;

    sum = a_value + b_value;
    product = sum * 4.0f;
    out = (int)product;
    out_value = out;

    if (out == 15) {
        rv32i_led_write(0x15u);
    } else {
        rv32i_led_write(0xe0u | ((u32)out & 0x0fu));
    }

    while (1) {
    }
}
