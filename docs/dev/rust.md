# Rust 裸机程序支持规划

本文记录让当前 RV32I CPU 运行 Rust `no_std` 裸机程序前需要补齐的硬件和软件条件. 当前目标不是运行操作系统, 而是先运行一个很小的 Rust 函数, 能访问 MMIO, 能用 UART 或 LED 输出可观察结果.

## 运行目标

第一阶段目标:

- 使用 `riscv32i-unknown-none-elf` 或等价 RV32I 裸机目标.
- 程序从 ROM 启动.
- 栈, `.data`, `.bss` 放在 RAM.
- 通过 MMIO 访问 LED, HEX, UART TX.
- 不使用标准库, 不使用操作系统.

暂时不做:

- Linux 或其他操作系统.
- MMU, cache, 用户态和特权态隔离.
- 中断和完整 CSR.
- `M`, `C`, `A`, `F`, `D` 等扩展.
- SDRAM 作为第一阶段必须条件.

## CPU 侧最低要求

Rust 编译器即使在 `no_std` 下, 也会生成比较完整的 RV32I 基础指令. CPU 需要至少覆盖 RV32I base integer:

| 类型 | 指令 |
| --- | --- |
| U-type | `LUI`, `AUIPC` |
| Jumps | `JAL`, `JALR` |
| Branch | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` |
| Load | `LB`, `LH`, `LW`, `LBU`, `LHU` |
| Store | `SB`, `SH`, `SW` |
| I-type ALU | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` |
| R-type ALU | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` |

需要特别检查的语义:

- `x0` 永远读出 0, 写入无效果.
- `JAL` 和 `JALR` 写回 `pc + 4`.
- `JALR` 的目标地址需要清除 bit 0.
- 有符号比较和无符号比较不能混用.
- load 的符号扩展和零扩展要正确.
- store 的 byte enable 和写数据对齐要正确.
- 移位量只使用低 5 bit.
- 自然对齐访问先作为第一阶段约束, 未对齐访问可以进入停机或非法指令路径.

## RAM 和内存布局

Rust 程序不能只依赖 ROM. 它至少需要 RAM 支持:

- 栈, 用于函数调用, 局部变量和返回地址保存.
- `.bss`, 用于零初始化全局变量.
- `.data`, 用于带初始值的全局变量.
- 可能的临时内存, 用于编译器生成的辅助逻辑.

第一阶段可以继续使用片上 `simple_ram`, 但建议 RAM 至少预留几 KB. 后续接 SDRAM 时, 再把 data memory 放到更大的地址空间.

建议内存布局先保持简单:

| 区域 | 建议地址 | 作用 |
| --- | --- | --- |
| ROM | `0x0000_0000` | `.text`, `.rodata`, 启动代码 |
| RAM | `0x0000_1000` 或独立 RAM 窗口 | `.data`, `.bss`, stack |
| MMIO | `0x0100_0000` | LED, HEX, UART 等外设 |

如果 ROM 和 RAM 暂时共享 `0x0000_0000` 大范围, 需要在 SoC 层明确取指走 ROM, 数据访问走 RAM. 这是当前 Harvard 结构可以接受的简化.

## 启动代码

CPU reset 后不能直接跳到 Rust `main`. 需要一段启动代码负责初始化运行环境:

1. 设置 `sp` 到栈顶.
2. 可选设置 `gp`.
3. 把 `.data` 从 ROM 拷贝到 RAM.
4. 把 `.bss` 清零.
5. 跳转到 Rust 入口函数, 例如 `rust_main`.
6. 如果 `rust_main` 返回, 进入死循环或写调试寄存器.

启动代码可以先用 `startup.S` 实现. 等流程稳定后再考虑把更多初始化逻辑搬到 Rust.

## linker script

需要一个 `linker.ld` 明确各段放在哪里. 第一版至少需要定义:

- ROM 起始地址和长度.
- RAM 起始地址和长度.
- `_stext`, `_etext`.
- `_sidata`, `_sdata`, `_edata`.
- `_sbss`, `_ebss`.
- `_stack_top`.

这些符号会被 `startup.S` 使用, 用于搬运 `.data`, 清零 `.bss`, 设置栈指针.

## Rust 侧最小工程

第一版 Rust 工程建议:

- `#![no_std]`
- `#![no_main]`
- 自定义 `panic_handler`.
- 入口函数使用 `#[no_mangle] extern "C" fn rust_main() -> !`.
- 使用 `core::ptr::{read_volatile, write_volatile}` 访问 MMIO.
- 先不使用 allocator.
- 先不使用格式化输出宏, 避免引入过多代码.

最小可观察程序可以先做:

- 写 LEDR.
- 写 HEX.
- 通过 UART TX 输出一个固定字符.

## UART 调试通道

为了调 Rust, 建议尽早增加 UART TX. 没有输出通道时, Rust 程序是否真的跑到某个位置很难判断.

第一阶段推荐先做 MMIO 级别的 UART TX 事件:

| 地址 | 名称 | 方向 | 有效位 | 作用 |
| --- | --- | --- | --- | --- |
| `0x0100_0020` | `UART_TXDATA` | W | `[7:0]` | 写入一个待发送字节 |

硬件上可以先拆成两步:

1. `uart_tx_mmio`: CPU 写 `UART_TXDATA` 时产生 `tx_valid` 和 `tx_data`.
2. `uart_tx`: 根据 `tx_valid`, `tx_data` 产生真实串口 TX 波形.

仿真阶段可以只检查 `tx_valid` 和 `tx_data`. 上板阶段再把真实 `uart_tx` 端口约束到 FPGA GPIO, 外接 USB-TTL 模块.

## 不需要立即实现的能力

这些能力对第一版 Rust 裸机程序不是硬性要求:

- `M` 扩展. 乘除法可以先由编译器运行时库或软件函数处理.
- 中断. 第一版可以轮询 MMIO.
- CSR 完整实现. 第一版不进入复杂 trap 流程时可以暂缓.
- SDRAM. 第一版程序足够小时, 片上 RAM 可以先支撑启动.
- cache 和流水线. 当前目标是可运行和可调试.

## 推荐推进顺序

1. 用 testbench 核对已实现指令是否覆盖完整 RV32I.
2. 增加 UART TX MMIO, 先在仿真中观察字符事件.
3. 增大或确认 `simple_ram` 可用容量.
4. 新建 Rust 裸机目录, 添加 `linker.ld`, `startup.S`, `main.rs`.
5. 建立 `ELF -> bin -> hex` 固件转换流程.
6. 先运行只写 LED 的 Rust 程序.
7. 再运行 UART 输出字符的 Rust 程序.
8. 最后再考虑 `.data`, `.bss`, 栈压力和更复杂函数调用.

