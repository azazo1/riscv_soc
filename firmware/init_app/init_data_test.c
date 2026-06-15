#include "rv32i_soc.h"

static volatile u32 data_value = 0x12345678u;
static volatile u32 bss_value;

int main(void)
{
    u32 out;

    out = 0u;
    if (data_value == 0x12345678u) {
        out |= 1u;
    }
    if (bss_value == 0u) {
        out |= 2u;
    }

    rv32i_led_write(out);

    while (1) {
    }
}
