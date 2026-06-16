# SDRAM

DE1-SoC FPGA 侧带有 64 MiB SDRAM. 手册中描述为 `64MB (32Mx16) SDRAM on FPGA`, 数据总线宽度是 16 bit.

当前项目把它放在独立的大内存窗口:

| 地址范围 | 大小 | 目标 |
| --- | --- | --- |
| `0x0200_0000` - `0x05ff_ffff` | 64 MiB | FPGA 侧 SDRAM |

这个窗口避开了低地址 ROM/RAM 和 `0x0100_xxxx` MMIO. 软件可以直接把它当普通指针使用:

```c
volatile u32 *p = (volatile u32 *)RV32I_SDRAM_BASE;
p[0] = 0x11223344u;
```

当前 VGA framebuffer 使用 SDRAM 起始区域:

| 地址范围 | 用途 |
| --- | --- |
| `0x0200_0000` 起 | VGA `160x120x8bit` framebuffer |

framebuffer 大小是 `160 * 120 = 19200` bytes. 普通 SDRAM 测试可以覆盖这块区域, 但 VGA 显示会同步读出这里的数据. 如果后续应用同时使用图形和其他大块数据, 需要在软件中避开 framebuffer 区域.

当前 SD app 默认从 `0x0201_0000` 开始加载和执行. 这个地址避开 framebuffer 起始区域, 也给后续图形程序留出更清晰的地址边界.

## 和片上 RAM 的关系

当前 SoC 不再尝试把大程序区放进片上 RAM. 低地址 boot RAM 只保留 4 KiB:

| 地址范围 | 大小 | 用途 |
| --- | --- | --- |
| `0x0000_f000` - `0x0000_ffff` | 4 KiB | bootloader `.bss`, sector buffer, stack |

这个 boot RAM 由 `onchip_dual_port_ram` 适配 Quartus `onchip_ram` IP 实现. Quartus Fitter 报告里应能看到 `onchip_ram:u_onchip_ram|altsyncram` 使用 M10K block.

普通应用从 SD 卡的 `INIT.BIN` 加载到 SDRAM, 默认入口地址是 `0x0201_0000`. 这样做的目的有两个:

1. boot RAM 保持很小, 资源占用可控.
2. app 可以使用更大的 `.text`, `.rodata`, `.data`, `.bss` 和 stack 空间.

如果 Fitter 报告中 `M10K blocks` 为 0, 但寄存器或 LAB 数量异常升高, 通常说明某个片上存储器没有映射到 block RAM. 这时应先检查 RAM/ROM 实现方式, 不要直接继续增加片上数组容量.

## 当前结构

```text
rv32i_core
  imem_addr + imem_ready
    -> rv32i_soc imem mux
        -> simple_rom
        -> onchip_dual_port_ram
        -> sdram_arbiter
            -> sdram_ctrl_wrapper

  dmem_* + dmem_ready
    -> simple_bus
        -> onchip_dual_port_ram
        -> gpio_mmio
        -> uart_tx_mmio
        -> spi_master_mmio
        -> sdram_arbiter
            -> sdram_ctrl_wrapper
             -> DRAM_* pins
```

`simple_bus` 命中 SDRAM 窗口后, 会把地址减去 `0x0200_0000`, 再交给 `sdram_ctrl_wrapper`.

`sdram_ctrl_wrapper` 的 CPU 侧接口是一次请求一次完成:

- `req`: CPU 发起访问.
- `we`: 1 表示写, 0 表示读.
- `be`: 4 bit 字节写使能.
- `addr`: SDRAM 窗口内偏移地址.
- `wdata`: 写入数据.
- `rdata`: 读出数据.
- `ready`: 当前访问完成.

CPU 侧仍然是 32-bit 小端访问. 控制器内部会把一次 32-bit 访问拆成两个 16-bit SDRAM 访问.

## 控制器后端

`sdram_ctrl_wrapper` 保持 SoC 侧接口稳定, 内部可以选择两种实现:

| 后端 | 选择方式 | 用途 |
| --- | --- | --- |
| `sdram_simple_ctrl` | 默认 | Verilator 仿真和结构阅读 |
| `sdram_ref_adapter` + `Sdram_Control` | `USE_SDRAM_REF_CTRL=1` | Quartus 上板路径 |

`sdram_simple_ctrl` 是本项目的教学版控制器. 它直接输出 SDRAM 命令, 并用 `~clk` 作为 SDRAM 时钟.

`Sdram_Control` 来自 DE1-SoC SDRAM 参考工程. 它不是 Avalon SDRAM Controller IP, 而是由 Verilog 控制逻辑, FIFO IP 和 PLL IP 组成的软控制器. 它的主机侧是 16-bit FIFO 流式接口, 所以本项目用 `sdram_ref_adapter` 把它适配成当前 SoC 使用的 32-bit `req/ready` 接口.

参考控制器没有 byte enable. 当 CPU 执行 `SB` 或 `SH` 这类部分字节写入时, `sdram_ref_adapter` 会先读出原来的 32-bit word, 合并需要更新的字节, 再写回两个 16-bit halfword.

Quartus 工程通过 QSF 打开参考控制器路径:

```tcl
set_global_assignment -name VERILOG_MACRO "USE_SDRAM_REF_CTRL=1"
set_global_assignment -name QIP_FILE src/soc/sdram/ref_ctrl/Sdram_RD_FIFO.qip
set_global_assignment -name QIP_FILE src/soc/sdram/ref_ctrl/Sdram_WR_FIFO.qip
set_global_assignment -name QIP_FILE src/soc/sdram/ref_ctrl/sdram_pll0.qip
```

`justfile` 自动收集 Verilog 源文件时排除 `src/soc/sdram/ref_ctrl/*`, 避免 Verilator 编译 Quartus PLL/FIFO IP. 本地仿真不定义 `USE_SDRAM_REF_CTRL`, 因此仍使用 `sdram_simple_ctrl`.

## CPU 等待

SDRAM 是多周期设备, 不能像早期 `simple_ram` 一样组合读. 因此 `rv32i_core` 使用 `imem_ready` 和 `dmem_ready` 等待取指或数据访问完成.

当 `imem_ready=0` 或 `dmem_req=1` 且 `dmem_ready=0` 时:

- `pc_reg` 保持当前 PC.
- `regfile` 不写回.
- 当前 load/store 指令继续停在同一个周期语义上等待.

ROM 和 MMIO 访问在 `simple_bus` 中直接返回 `ready=1`. 片上 RAM 和 SDRAM 访问会等待对应存储模块完成. SDRAM 取指在 `rv32i_soc` 中有一个单 word cache, 用来避免同一个 PC 在等待期间重复发起请求.

## SDRAM 时序

第一版控制器做的是保守单次访问:

1. 上电等待.
2. precharge all.
3. refresh.
4. refresh.
5. load mode.
6. idle.
7. 每次访问执行 activate, read/write low half, read/write high half, auto-precharge.

当前 `sdram_clk` 使用 `~clk`, 也就是让 SDRAM 在控制器输出命令半个周期后采样. 这比同沿采样更适合外部 SDRAM. 上板后仍然需要看 Quartus timing, 后续可以用 PLL 输出带相位偏移的 SDRAM clock.

参考控制器路径使用 `sdram_pll0` 生成内部 SDRAM 控制时钟和外部 SDRAM 时钟. 该 PLL 当前来自参考工程, 输出 100 MHz 控制时钟, 外部 SDRAM 时钟带相位偏移.

## 测试

运行:

```shell
just test-sdram-simple-ctrl
just test-sdram-ctrl-wrapper
```

测试内容:

- 缩短初始化等待.
- 写入 32-bit word 后读回.
- 用 `be` 测试部分字节写.
- 写另一个地址后读回.

`sdram_model.v` 只用于 testbench. 它不是完整 SDRAM 芯片模型, 只用来验证本项目控制器的命令顺序和基本读写.

## 上板自检程序

当前提供了一个 SDRAM 自检 C 程序:

```text
apps/sdram_test/main.c
```

生成 binary:

```shell
just build-app-sdram-test
```

输出文件:

```text
build/apps/sdram_test/sdram_test.bin
```

如果要用现有 SD bootloader 上板运行, 可以把 `sdram_test.bin` 放到 FAT32 SD 卡根目录, 文件名改成 `INIT.BIN`.

程序现象:

- UART 输出 `SDRAM test\n`.
- LEDR 初始为 `0x001`.
- 写读多个 SDRAM word 地址, 包括起始地址和靠近 64 MiB 末尾的地址.
- 额外用 byte store 检查 4 个 byte lane.
- 通过后 LEDR 显示 `0x3ff`, UART 输出 `SDRAM PASS\n`.
- 失败时 LEDR[9] 闪烁, 低 8 bit 显示失败步骤, UART 输出 step, index, expected, actual.

对应仿真:

```shell
just test-rv32i-soc-sdram-app
```

这个测试会把 `sdram_test.bin` 转成临时 hex, 预装到 SDRAM 的 `0x0201_0000` 偏移处, 从 `0x0201_0000` 启动, 再通过 `sdram_model` 检查程序能走到 LEDR `0x3ff`.

## 后续

当前 SDRAM 已经可以作为 data bus 和 app 取指的大容量窗口. 更完整的方向:

1. 写一个上板 SDRAM 自检程序, 用 LED/UART 显示 pass/fail.
2. 用 Quartus 编译并检查 `dram_clk` 相关 timing.
3. 如果 50 MHz 稳定, 再考虑 PLL 提升到 100 MHz.
4. 给 SDRAM 取指增加更正式的 icache 或 burst 读取.
5. 如果要稳定驱动 VGA 动画, 给 VGA 路径增加 line FIFO 或 DMA 预取.
