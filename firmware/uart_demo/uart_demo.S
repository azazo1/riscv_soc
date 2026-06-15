# uart_demo.S -- UART board test program
# 功能:
#   1. 启动后发送 "R\n", 方便确认 reset 后程序已经执行.
#   2. 每约 1 秒发送 ".\n", 方便确认 UART 持续工作.
#   3. KEY 状态变化时发送 "Kx\n", x 是 KEY[3:0] 的十六进制值.
#
# 说明:
#   DE1-SoC 的 KEY 通常是低有效, 未按下时读到 0xf.
#   例如 KEY0 按下时常见读数是 0xe.
#
# 内存映射:
#   0x0100_0000 LEDR
#   0x0100_0008 KEY
#   0x0100_0100 UART_TXDATA
#   0x0100_0104 UART_STATUS

.text
.globl _start
_start:
    lui  x1, 0x01000          # x1 = MMIO base 0x0100_0000

    addi x2, x0, 1
    sw   x2, 0(x1)            # LEDR[0] = 1, 表示程序已经启动.

    lw   x8, 8(x1)            # x8 保存上一次 KEY[3:0] 状态.
    andi x8, x8, 15

    addi x5, x0, 82           # 'R'
    jal  x7, uart_putc
    addi x5, x0, 10           # '\n'
    jal  x7, uart_putc

main_loop:
    addi x20, x0, 100         # 100 * 10 ms, 约等于 1 秒.

one_second_loop:
    jal  x9, delay_10ms

    lw   x11, 8(x1)           # 读取 KEY.
    andi x11, x11, 15         # 只保留 KEY[3:0].
    beq  x11, x8, no_key_event

    add  x8, x0, x11          # 状态变化后更新旧值.
    jal  x9, send_key_event

no_key_event:
    addi x20, x20, -1
    bne  x20, x0, one_second_loop

    addi x5, x0, 46           # '.'
    jal  x7, uart_putc
    addi x5, x0, 10           # '\n'
    jal  x7, uart_putc

    beq  x0, x0, main_loop

uart_putc:
    lw   x6, 260(x1)          # UART_STATUS, bit 0 是 tx_ready.
    andi x6, x6, 1
    beq  x6, x0, uart_putc

    sw   x5, 256(x1)          # UART_TXDATA, 只使用低 8 bit.
    jalr x0, 0(x7)

send_key_event:
    addi x5, x0, 75           # 'K'
    jal  x7, uart_putc

    add  x5, x0, x8           # 把 KEY[3:0] 转成一个 hex 字符.
    addi x6, x0, 10
    blt  x5, x6, key_hex_digit

    addi x5, x5, 87           # 10 -> 'a'
    beq  x0, x0, key_hex_done

key_hex_digit:
    addi x5, x5, 48           # 0 -> '0'

key_hex_done:
    jal  x7, uart_putc
    addi x5, x0, 10           # '\n'
    jal  x7, uart_putc
    jalr x0, 0(x9)

delay_10ms:
    lui  x10, 0x0003d
    addi x10, x10, 0x090      # x10 = 250000.

delay_10ms_loop:
    addi x10, x10, -1
    bne  x10, x0, delay_10ms_loop
    jalr x0, 0(x9)
