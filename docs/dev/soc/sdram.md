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

## 当前结构

```text
rv32i_core
  imem_addr + imem_ready
    -> rv32i_soc imem mux
        -> simple_rom
        -> simple_dual_port_ram
        -> sdram_arbiter
            -> sdram_simple_ctrl

  dmem_* + dmem_ready
    -> simple_bus
        -> simple_dual_port_ram
        -> gpio_mmio
        -> uart_tx_mmio
        -> spi_master_mmio
        -> sdram_arbiter
            -> sdram_simple_ctrl
             -> DRAM_* pins
```

`simple_bus` 命中 SDRAM 窗口后, 会把地址减去 `0x0200_0000`, 再交给 `sdram_simple_ctrl`.

`sdram_simple_ctrl` 的 CPU 侧接口是一次请求一次完成:

- `req`: CPU 发起访问.
- `we`: 1 表示写, 0 表示读.
- `be`: 4 bit 字节写使能.
- `addr`: SDRAM 窗口内偏移地址.
- `wdata`: 写入数据.
- `rdata`: 读出数据.
- `ready`: 当前访问完成.

CPU 侧仍然是 32-bit 小端访问. 控制器内部会把一次 32-bit 访问拆成两个 16-bit SDRAM 访问.

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

## 测试

运行:

```shell
just test-sdram-simple-ctrl
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
