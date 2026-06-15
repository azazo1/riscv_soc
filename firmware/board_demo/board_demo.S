# board_demo.S -- 上板自检汇编程序
# 功能:
#   1. 运行 ALU, branch, RAM, MMIO 的最小自检
#   2. 全部通过时 LEDR[3:0] = 1111, HEX0 显示 0
#   3. 失败时 LEDR 显示错误码, HEX0 显示错误码
#
# 错误码:
#   0 = 全部通过
#   1 = ALU 或 x0 自检失败
#   2 = branch 自检失败
#   3 = RAM load/store 自检失败
#
# 内存映射:
#   0x0000_0000  IMEM
#   0x0000_8000  RAM
#   0x0100_0000  LEDR
#   0x0100_0004  SW
#   0x0100_0008  KEY
#   0x0100_000c  HEX_LOW
#   0x0100_0010  HEX_HIGH

.text
.globl _start
_start:
    lui  x1, 0x01000          # x1 = MMIO 基地址 0x0100_0000

    addi x30, x0, 0           # x30 = error code
    addi x31, x0, 0           # x31 = pass bit mask

test_alu:
    addi x0, x0, 1            # x0 必须保持为 0
    bne  x0, x30, fail_alu

    addi x2, x0, 1
    addi x3, x0, 2
    add  x4, x2, x3           # 1 + 2 = 3
    addi x5, x0, 3
    bne  x4, x5, fail_alu

    sub  x4, x5, x2           # 3 - 1 = 2
    bne  x4, x3, fail_alu

    slli x4, x2, 4            # 1 << 4 = 16
    addi x5, x0, 16
    bne  x4, x5, fail_alu

    srli x4, x5, 2            # 16 >> 2 = 4
    addi x6, x0, 4
    bne  x4, x6, fail_alu

    ori  x31, x31, 1          # ALU pass
    beq  x0, x0, test_branch

fail_alu:
    addi x30, x0, 1
    beq  x0, x0, finish

test_branch:
    addi x2, x0, 5
    addi x3, x0, 5
    beq  x2, x3, branch_beq_ok
    beq  x0, x0, fail_branch

branch_beq_ok:
    bne  x2, x3, fail_branch

    addi x4, x0, 4
    blt  x4, x2, branch_blt_ok
    beq  x0, x0, fail_branch

branch_blt_ok:
    bge  x4, x2, fail_branch

    ori  x31, x31, 2          # branch pass
    beq  x0, x0, test_ram

fail_branch:
    addi x30, x0, 2
    beq  x0, x0, finish

test_ram:
    lui  x20, 0x00008         # x20 = RAM base 0x0000_8000
    addi x20, x20, 128        # RAM 测试地址 0x0000_8080
    lui  x21, 0x12345
    addi x21, x21, 0x678      # x21 = 0x1234_5678
    sw   x21, 0(x20)
    lw   x22, 0(x20)
    bne  x22, x21, fail_ram

    ori  x31, x31, 4          # RAM pass
    beq  x0, x0, test_mmio

fail_ram:
    addi x30, x0, 3
    beq  x0, x0, finish

test_mmio:
    lw   x23, 4(x1)           # 读取 SW, 验证 MMIO read 路径可执行
    sw   x23, 0(x1)           # 短暂写入 LEDR, 验证 MMIO write 路径可执行
    ori  x31, x31, 8          # MMIO pass
    beq  x0, x0, finish

finish:
    bne  x30, x0, show_error
    sw   x31, 0(x1)           # 全部通过时 LEDR[3:0] = 1111
    beq  x0, x0, select_hex

show_error:
    sw   x30, 0(x1)           # 失败时 LEDR 显示错误码

select_hex:
    addi x2, x0, 0
    beq  x30, x2, hex_0
    addi x2, x0, 1
    beq  x30, x2, hex_1
    addi x2, x0, 2
    beq  x30, x2, hex_2
    addi x2, x0, 3
    beq  x30, x2, hex_3
    beq  x0, x0, hex_f

hex_0:
    addi x2, x0, 0x40
    beq  x0, x0, write_hex

hex_1:
    addi x2, x0, 0x79
    beq  x0, x0, write_hex

hex_2:
    addi x2, x0, 0x24
    beq  x0, x0, write_hex

hex_3:
    addi x2, x0, 0x30
    beq  x0, x0, write_hex

hex_f:
    addi x2, x0, 0x0e

write_hex:
    addi x3, x0, 0x7f         # 0x7f 表示熄灭一个 HEX digit
    slli x4, x3, 8
    or   x3, x3, x4           # x3 = 0x0000_7f7f
    slli x4, x3, 16
    or   x3, x3, x4           # x3 = 0x7f7f_7f7f
    add  x5, x0, x3           # x5 保存 HEX_HIGH 的熄灭值
    addi x3, x3, -127         # x3 = 0x7f7f_7f00
    add  x3, x3, x2           # HEX0 显示错误码, HEX1..HEX3 熄灭
    sw   x3, 12(x1)
    sw   x5, 16(x1)           # HEX4..HEX5 熄灭

done:
    beq  x0, x0, done
