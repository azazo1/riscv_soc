# imm_gen

`imm_gen` 是立即数生成器. 它输入一条 32 bit 指令 `instr`, 从指令中取出 immediate, 并扩展成 32 bit 数据.

立即数不是从寄存器读出来的值, 而是编码在指令机器码里的常数. 例如 `addi x1, x2, 5` 中的 `5` 就是 immediate.

## 为什么单独做模块

RV32I 的 immediate 不都放在同一段连续 bit 中. I-type 和 U-type 比较直观, B-type 和 J-type 会把 offset 拆散到多个位置. 如果把这些拼接逻辑直接写进 CPU 顶层, 后面不容易检查, 也不容易测试.

所以第一版把 immediate 生成拆成一个纯组合逻辑模块:

- 输入: `instr[31:0]`.
- 输出: `imm_i`, `imm_s`, `imm_b`, `imm_u`, `imm_j`.
- 不需要 `clk`.
- 不需要 `rst_n`.

## 五种 immediate

RV32I 的 32 bit 指令里, `opcode`, `rd`, `funct3`, `rs1`, `rs2`, `funct7` 等字段位置比较固定. immediate 为了照顾不同指令格式, 会被放在不同位置. 生成 `imm_*` 时, 目标都是得到一个已经扩展到 32 bit 的值.

| 类型 | 常见指令 | 原始 immediate 宽度 | 生成后最低位 | 是否符号扩展 |
|---|---|---:|---|---|
| I-type | `addi`, `lw`, `jalr` | 12 bit | 来自 `instr[20]` | 是 |
| S-type | `sb`, `sh`, `sw` | 12 bit | 来自 `instr[7]` | 是 |
| B-type | `beq`, `bne`, `blt` | 13 bit | 固定为 `1'b0` | 是 |
| U-type | `lui`, `auipc` | 32 bit 结果中的高 20 bit | 固定为 `12'b0` 的最低位 | 否 |
| J-type | `jal` | 21 bit | 固定为 `1'b0` | 是 |

### I-type

用于 `addi`, `andi`, `ori`, `lw`, `jalr` 等指令.

```text
imm_i = sign_extend(instr[31:20])
```

I-type 的 immediate 在指令中是连续的:

| 生成后的 bit | 来源 |
|---|---|
| `imm_i[31:12]` | 复制 `instr[31]` |
| `imm_i[11:0]` | `instr[31:20]` |

重点:

- immediate 原始宽度是 12 bit.
- 符号位是 `instr[31]`.
- 高 20 bit 用 `instr[31]` 复制填充.

### S-type

用于 `sb`, `sh`, `sw` 等 store 指令.

```text
imm_s = sign_extend({instr[31:25], instr[11:7]})
```

S-type 的 immediate 被 `rs2`, `rs1`, `funct3` 隔开, 所以要拼回 12 bit:

| 生成后的 bit | 来源 |
|---|---|
| `imm_s[31:12]` | 复制 `instr[31]` |
| `imm_s[11:5]` | `instr[31:25]` |
| `imm_s[4:0]` | `instr[11:7]` |

重点:

- immediate 被拆成两段.
- 高段在 `instr[31:25]`.
- 低段在 `instr[11:7]`.
- 符号位仍然是 `instr[31]`.

### B-type

用于 `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` 等 branch 指令.

```text
imm_b = sign_extend({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0})
```

B-type 是分支 offset. 因为 RV32I 基础指令按 2 byte 对齐来编码 offset, 所以最低位不用存在指令里, 生成时补 `1'b0`.

| 生成后的 bit | 来源 |
|---|---|
| `imm_b[31:13]` | 复制 `instr[31]` |
| `imm_b[12]` | `instr[31]` |
| `imm_b[11]` | `instr[7]` |
| `imm_b[10:5]` | `instr[30:25]` |
| `imm_b[4:1]` | `instr[11:8]` |
| `imm_b[0]` | `1'b0` |

重点:

- branch offset 的最低位固定为 0.
- 生成出来的 `imm_b` 可以直接和 `pc` 相加.
- 位顺序容易写错, 尤其是 `instr[7]` 和 `instr[11:8]`.

### U-type

用于 `lui`, `auipc`.

```text
imm_u = {instr[31:12], 12'b0}
```

U-type 的指令字段本身就代表结果的高 20 bit:

| 生成后的 bit | 来源 |
|---|---|
| `imm_u[31:12]` | `instr[31:12]` |
| `imm_u[11:0]` | `12'b0` |

重点:

- U-type 不需要符号扩展成普通 12 bit immediate.
- 指令里的高 20 bit 直接放到结果的 `[31:12]`.
- 低 12 bit 补 0.

### J-type

用于 `jal`.

```text
imm_j = sign_extend({instr[31], instr[19:12], instr[20], instr[30:21], 1'b0})
```

J-type 是跳转 offset. 它和 B-type 一样, 最低位不存进指令, 生成时补 `1'b0`.

| 生成后的 bit | 来源 |
|---|---|
| `imm_j[31:21]` | 复制 `instr[31]` |
| `imm_j[20]` | `instr[31]` |
| `imm_j[19:12]` | `instr[19:12]` |
| `imm_j[11]` | `instr[20]` |
| `imm_j[10:1]` | `instr[30:21]` |
| `imm_j[0]` | `1'b0` |

重点:

- jump offset 的最低位固定为 0.
- 生成出来的 `imm_j` 可以直接和 `pc` 相加.
- 位顺序比 B-type 更容易看错, 写之前最好先按字段抄一遍.

## 实现顺序建议

先不要一次写完所有格式. 建议按下面顺序推进:

1. 先实现 `imm_i`, 只测正数和负数.
2. 再实现 `imm_s`, 重点测 store 的负偏移.
3. 再实现 `imm_u`, 因为它没有符号扩展, 比较容易确认.
4. 再实现 `imm_b`, 重点测正偏移和负偏移.
5. 最后实现 `imm_j`, 重点测正偏移和负偏移.

## 测试重点

`imm_gen_vlg_tst` 不需要覆盖很多文案场景, 只需要覆盖最容易写错的语义:

- I-type 正数, 例如 `0x123`.
- I-type 负数, 例如 `-1`.
- S-type 负偏移, 例如 `-16`.
- U-type 低 12 bit 是否补 0.
- B-type 正偏移和负偏移.
- J-type 正偏移和负偏移.

测试 B-type 和 J-type 时, 建议先在 testbench 里定义一个期望 offset, 再按 RISC-V 编码规则把它拆回 `instr` 对应 bit. 这样测试代码能反过来检查 `imm_gen` 是否把这些 bit 拼回原来的 offset.

## 常见错误

- 忘记符号扩展, 导致负 immediate 变成很大的正数.
- B-type 忘记补最低位 `1'b0`.
- J-type 忘记补最低位 `1'b0`.
- 把 B-type 的 `instr[7]` 放错位置.
- 把 J-type 的 `instr[20]` 放错位置.
- 把 U-type 当作 12 bit immediate 去符号扩展.
