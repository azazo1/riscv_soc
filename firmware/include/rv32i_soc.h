#ifndef RV32I_SOC_H
#define RV32I_SOC_H

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;

#define RV32I_REG32(addr) (*(volatile u32 *)(addr))

#define RV32I_SDRAM_BASE  0x02000000u
#define RV32I_SDRAM_SIZE  0x04000000u
#define RV32I_SDRAM_END   0x06000000u
#define RV32I_APP_BASE    0x02010000u

#define RV32I_VGA_FB_BASE    RV32I_SDRAM_BASE
#define RV32I_VGA_FB_WIDTH   160u
#define RV32I_VGA_FB_HEIGHT  120u
#define RV32I_VGA_FB_PIXELS  (RV32I_VGA_FB_WIDTH * RV32I_VGA_FB_HEIGHT)

/* MMIO register map. */
#define RV32I_LEDR      RV32I_REG32(0x01000000u)
#define RV32I_SW        RV32I_REG32(0x01000004u)
#define RV32I_KEY       RV32I_REG32(0x01000008u)
#define RV32I_HEX_LOW   RV32I_REG32(0x0100000cu)
#define RV32I_HEX_HIGH  RV32I_REG32(0x01000010u)

#define RV32I_UART_TXDATA  RV32I_REG32(0x01000100u)
#define RV32I_UART_STATUS  RV32I_REG32(0x01000104u)

#define RV32I_SPI_TXDATA  RV32I_REG32(0x01000200u)
#define RV32I_SPI_RXDATA  RV32I_REG32(0x01000204u)
#define RV32I_SPI_STATUS  RV32I_REG32(0x01000208u)
#define RV32I_SPI_CTRL    RV32I_REG32(0x0100020cu)
#define RV32I_SPI_DIV     RV32I_REG32(0x01000210u)

#define RV32I_UART_TX_READY  0x00000001u
#define RV32I_UART_TX_BUSY   0x00000002u
#define RV32I_SPI_READY      0x00000001u
#define RV32I_SPI_BUSY       0x00000002u

/* Short aliases, close to the style of MCU register header files. */
#define LEDR            RV32I_LEDR
#define SW              RV32I_SW
#define KEY             RV32I_KEY
#define HEX_LOW         RV32I_HEX_LOW
#define HEX_HIGH        RV32I_HEX_HIGH
#define UART_TXDATA     RV32I_UART_TXDATA
#define UART_STATUS     RV32I_UART_STATUS
#define UART_TX_READY   RV32I_UART_TX_READY
#define UART_TX_BUSY    RV32I_UART_TX_BUSY
#define SPI_TXDATA      RV32I_SPI_TXDATA
#define SPI_RXDATA      RV32I_SPI_RXDATA
#define SPI_STATUS      RV32I_SPI_STATUS
#define SPI_CTRL        RV32I_SPI_CTRL
#define SPI_DIV         RV32I_SPI_DIV
#define SPI_READY       RV32I_SPI_READY
#define SPI_BUSY        RV32I_SPI_BUSY

static inline void rv32i_led_write(u32 value)
{
    RV32I_LEDR = value;
}

static inline u32 rv32i_sw_read(void)
{
    return RV32I_SW;
}

static inline u32 rv32i_key_read(void)
{
    return RV32I_KEY;
}

static inline void rv32i_uart_wait_ready(void)
{
    while ((RV32I_UART_STATUS & RV32I_UART_TX_READY) == 0u) {
    }
}

static inline void rv32i_uart_wait_done(void)
{
    while ((RV32I_UART_STATUS & RV32I_UART_TX_BUSY) != 0u) {
    }
}

static inline void rv32i_uart_putc(char ch)
{
    rv32i_uart_wait_ready();
    RV32I_UART_TXDATA = (u32)(u8)ch;
    rv32i_uart_wait_done();
}

static inline void rv32i_uart_puts(const char *text)
{
    while (*text != '\0') {
        rv32i_uart_putc(*text);
        text++;
    }
}

static inline void rv32i_uart_put_hex4(u32 value)
{
    value &= 0x0fu;
    if (value < 10u) {
        rv32i_uart_putc((char)('0' + value));
    } else {
        rv32i_uart_putc((char)('a' + value - 10u));
    }
}

static inline void rv32i_spi_wait_ready(void)
{
    while ((RV32I_SPI_STATUS & RV32I_SPI_READY) == 0u) {
    }
}

static inline void rv32i_spi_set_cs(u32 cs_n)
{
    RV32I_SPI_CTRL = cs_n & 1u;
}

static inline void rv32i_spi_set_div(u32 div)
{
    RV32I_SPI_DIV = div;
}

static inline u8 rv32i_spi_transfer(u8 value)
{
    rv32i_spi_wait_ready();
    RV32I_SPI_TXDATA = (u32)value;
    rv32i_spi_wait_ready();
    return (u8)RV32I_SPI_RXDATA;
}

#endif
