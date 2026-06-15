# board_demo.S -- 上板测试汇编程序
# 功能:
#   1. 初始化 HEX 段码, HEX0 到 HEX5 分别显示 0 到 5
#   2. 循环读取 SW[9:0] 并镜像到 LEDR[9:0]
#
# 内存映射 (MMIO, 基址 0x0100_0000):
#   0x0100_0000  LEDR      R/W, 低 10 bit 有效
#   0x0100_0004  SW        R,   低 10 bit 有效
#   0x0100_0008  KEY       R,   低  4 bit 有效
#   0x0100_000c  HEX_LOW   R/W, HEX0..HEX3, 每个 8 bit (低 7 bit 有效)
#   0x0100_0010  HEX_HIGH  R/W, HEX4..HEX5, 低 2 bytes 有效

.text
.globl _start
_start:

    # x1 = MMIO 基地址 0x0100_0000
    lui  x1, 0x01000

    # HEX0..HEX3 段码: 0=0x40, 1=0x79, 2=0x24, 3=0x30
    # 组合为 32-bit: {hex3, hex2, hex1, hex0} = 0x30247940
    lui  x2, 0x30248          # x2 = 0x3024_8000
    addi x2, x2, -1728        # x2 = 0x3024_7940
    sw   x2, 0x0c(x1)         # 写入 HEX_LOW

    # HEX4..HEX5 段码: 4=0x19, 5=0x12
    # 组合为: {0, hex5, hex4} = 0x00001219
    lui  x3, 0x00001          # x3 = 0x0000_1000
    addi x3, x3, 537          # x3 = 0x0000_1219
    sw   x3, 0x10(x1)         # 写入 HEX_HIGH

loop:
    lw   x4, 0x04(x1)         # 读取 SW (0x0100_0004)
    sw   x4, 0x00(x1)         # 写入 LEDR (0x0100_0000)
    beq  x0, x0, loop         # 无条件跳回 loop

    # 不会到达这里
    ebreak
