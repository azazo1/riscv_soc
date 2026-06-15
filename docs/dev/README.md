# 开发文档

这个目录用于记录 RV32I CPU 和 SoC 的开发说明. 文档尽量围绕当前阶段的问题展开, 不提前堆太多后面才会用到的细节.

## 当前阅读顺序

1. `core/regs.md`: 先理解 RV32I 的 32 个通用寄存器, 特别是 `x0` 恒为 0, 以及 `pc` 不属于通用寄存器堆.
2. `core/arch.md`: 再看第一版 CPU 的数据通路, 控制信号和模块边界.
3. `core/instr_format.md`: 看 R/I/S/B/U/J 六种指令格式, 先熟悉字段位置.
4. `core/imm_gen.md`: 写立即数生成器之前, 先确认 I/S/B/U/J 五种 immediate 的位拼接和符号扩展.
5. `soc/README.md`: CPU 顶层能运行后, 看最小 SoC 的 ROM, RAM 和后续 SDRAM 接入规划.
6. `rust.md`: 准备运行 Rust 裸机程序前, 核对 CPU 指令, RAM, 启动代码和调试输出要求.

## 当前开发节奏

第一版先按小模块推进, 每个模块都配一个独立 testbench. 这样 CPU 顶层还没有写完时, 也能先确认基础部件的行为.

推荐顺序如下:

1. `regfile`: 通用寄存器堆, 重点验证 `x0` 和同步写入.
2. `alu`: 整数运算单元, 重点验证有符号比较, 无符号比较和移位.
3. `imm_gen`: 立即数生成器, 重点验证 I/S/B/U/J 格式的位拼接和符号扩展.
4. `decoder`: 指令译码, 把 opcode, funct3, funct7 转成控制信号.
5. `branch_unit`: 分支判断, 独立验证 BEQ, BNE, BLT, BGE, BLTU, BGEU.
6. `load_store_unit`: load/store 字节使能, 对齐和符号扩展.
7. `rv32i_core`: 连接 PC, regfile, ALU, decoder, memory 接口.
8. `rv32i_soc`: 连接 CPU, ROM, RAM, 从模块级测试推进到最小系统测试.

## 代码和测试约定

- Verilog 源码放在 `src/` 下.
- 构建输出统一放在 `build/` 下.
- 硬件 testbench 使用 `xxx_vlg_tst` 命名, 贴近 Quartus 自动生成 testbench 的风格.
- 每个关键模块优先写小测试, 不用一开始依赖完整 CPU.
- 测试不按文案覆盖, 只覆盖容易写错的硬件语义.

## 常用命令

列出可用 recipe:

```shell
just
```

运行全部已有测试:

```shell
just test
```

运行单个 Verilog top:

```shell
just run-verilog regfile_vlg_tst
```

清理构建产物:

```shell
just clean
```

## 设计原则

- 先让本地仿真闭环, 再考虑板级外设和 Quartus 工程.
- 第一版接口尽量简单, 不急着引入复杂总线协议.
- 遇到位拼接, 符号扩展, 地址对齐, 字节使能这些细节时, 优先单独写测试.
- 如果模块以后会被 CPU 顶层复用, 先保持接口清楚, 不把太多控制逻辑塞进一个文件.
