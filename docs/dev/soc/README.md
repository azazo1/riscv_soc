# SoC 开发说明

这个目录记录 CPU 外围封装的设计思路. 当前阶段已经从最小 ROM/RAM SoC 推进到带 data bus, GPIO MMIO, UART TX, SPI master 和 SDRAM 的小系统.

## 当前边界

当前 SoC 负责连接 CPU, 指令 ROM, 双口 RAM, 数据总线, GPIO MMIO, UART TX, SPI master, SDRAM.

- CPU 使用 `rv32i_core`.
- 取指地址在 `0x0000_0000` 到 `0x0000_7fff` 时读取 `simple_rom`, 在 `0x0000_8000` 到 `0x0000_ffff` 时读取 RAM.
- 数据读写从 core 发出, 先进入 `simple_bus`.
- `simple_bus` 按地址窗口选择 ROM 只读窗口, RAM, GPIO MMIO, UART TX MMIO, SPI MMIO 或 SDRAM.
- `simple_dual_port_ram` 同时提供 data bus 访问口和 RAM 取指口.
- `gpio_mmio` 提供 LEDR, SW, KEY, HEX0..HEX5, GPIO_0, GPIO_1 的寄存器访问.
- `uart_tx_mmio` 提供 UART TX 寄存器访问.
- `uart_tx` 负责产生 UART TX 串口波形.
- `spi_master_mmio` 提供外接 SPI SD 模块可用的基础 SPI 字节传输.
- `sdram_simple_ctrl` 提供 DE1-SoC FPGA 侧 64 MiB SDRAM 访问.
- 暂时没有 UART RX, timer, interrupt.
- data bus 已有 `ready` 等待信号, 当前主要用于 SDRAM.

这一阶段的目标是让 CPU 能通过普通 load/store 指令访问片上 RAM 和基础板载外设.

## 总体结构

```text
rv32i_core
  imem_addr  -> imem mux
                   -> simple_rom
                   -> simple_dual_port_ram imem port

  dmem_*     -> simple_bus
                   -> simple_rom (read-only)
                   -> simple_dual_port_ram data port
                   -> gpio_mmio
                   -> uart_tx_mmio -> uart_tx
                   -> spi_master_mmio -> external SPI SD module
                   -> sdram_simple_ctrl -> onboard SDRAM
```

当前仍然是 Harvard 接口. 取指接口独立连接 ROM/RAM mux, 数据接口连接 bus. 这样可以先避免取指和访存之间的仲裁问题.

## 模块分工

### `simple_rom`

`simple_rom` 是只读指令存储器.

- 输入 `addr`, 来自 CPU 的 `imem_addr`.
- 输出 `rdata`, 返回当前 PC 对应的 32 位指令.
- `addr` 是字节地址.
- RV32I 指令固定 4 字节, 所以可用 `addr[31:2]` 选择第几条指令.
- ROM 内容通过 `$readmemh` 从 hex 文件初始化.
- 默认 `ROM_FILE` 是 `firmware/board_demo/board_demo.hex`, 板级 `de1_soc_top` 默认改用 `firmware/bootloader/bootloader.hex`.
- `ROM_WORDS` 默认是 2048, 对应 8 KiB.
- `ROM_WORDS` 决定可访问的 word 数, 超出范围时返回 `32'h0000_0013`.
- 固件 hex 只包含实际固件 word, 未写入的 ROM 内容不作为稳定行为依赖.

固件源文件是 `firmware/board_demo/board_demo.S`. 运行 `just firmware-board-demo` 会重新生成 `firmware/board_demo/board_demo.hex`.

UART 实机测试固件是 `firmware/uart_demo/uart_demo.S`. 运行 `just firmware-uart-demo` 会生成 `firmware/uart_demo/uart_demo.hex`.

C 实机测试固件是 `firmware/c_demo/main.c`. 运行 `just firmware-c-demo` 会生成 `firmware/c_demo/c_demo.hex`.

SD 启动固件是 `firmware/bootloader/main.c`. 运行 `just firmware-bootloader` 会生成 `firmware/bootloader/bootloader.hex`.

`de1_soc_top` 默认使用 bootloader 固件. `rv32i_soc` 默认仍使用 `board_demo.hex`, 方便本地仿真保持快速自检.

`firmware/test/simple_rom.hex` 只给 `simple_rom_vlg_tst` 使用, 不作为上板程序.

`board_demo` 上板自检固件的行为:

- 运行 ALU, branch, RAM load/store, MMIO read/write 的最小自检.
- 全部通过时 `LEDR[3:0]` 显示 `1111`, `HEX0` 显示 `0`, `HEX1` 到 `HEX5` 熄灭.
- 失败时 `LEDR` 显示错误码, `HEX0` 显示错误码.

这样上板后可以不用串口, 直接通过 LED 和 HEX 判断 ROM 取指, CPU 执行, RAM 访问和 MMIO 访问是否跑通.

### `simple_ram`

`simple_ram` 是早期的数据存储器, 当前主要保留给单元测试和对照阅读.

- 输入 `req`, 表示 CPU 发起数据访问.
- 输入 `we`, 表示写访问.
- 输入 `be`, 表示字节写使能.
- 输入 `addr`, 表示字节地址.
- 输入 `wdata`, 表示写数据.
- 输出 `rdata`, 表示读数据.

第一版 RAM 使用组合读, 同步写. 这样可以匹配当前 `rv32i_core` 对 load 数据当周期可见的假设.

写入时按 `be` 分字节更新 32 位 word. 这样 `SB`, `SH`, `SW` 都可以共用同一个 RAM 模块.

### `simple_dual_port_ram`

`rv32i_soc` 当前使用 `simple_dual_port_ram`.

- data 口给 `simple_bus` 使用, 支持同步读写, 通过 `ready` 表示访问完成.
- imem 口给 CPU 从 RAM 取指使用, 只读, 通过 `imem_ready` 表示指令有效.
- RAM 本地地址从 0 开始, SoC 地址 `0x0000_8000` 对应 RAM 本地 word 0.
- 默认容量是 8192 words, 也就是 32 KiB.
- reset 不清空 RAM, 避免综合出很大的复位清零逻辑, 也更容易推断为 M10K.

后续查看 Quartus Fitter 报告时发现, 片上 RAM 可能没有被推断成 M10K block. 报告里 `Total RAM Blocks` 和 `M10K blocks` 为 0, 但寄存器数量达到二十多万级, 同时 LAB 需求超过两万. 这说明 `simple_dual_port_ram` 的 32 KiB 存储阵列被综合进了普通逻辑资源, 这才是当前面积超限的主要来源.

处理方向不是继续扩大片上 RAM, 而是缩小低地址 boot RAM, 把普通 app 加载到 SDRAM 执行. 片上 RAM 只保留给 bootloader 的 `.bss`, sector buffer 和 stack. 如果后续仍需要片上 RAM, 应优先确认它是否真正占用 M10K, 或使用规格匹配的 RAM IP.

### `simple_bus`

`simple_bus` 是当前的数据访问译码器.

- 接收 core 的 `dmem_req`, `dmem_we`, `dmem_be`, `dmem_addr`, `dmem_wdata`.
- 当地址落在 ROM 区间且是读访问时, 转发到只读 ROM.
- 当地址落在 RAM 区间时, 转发到 `simple_dual_port_ram` data 口.
- 当地址落在 GPIO MMIO 区间时, 转发到 `gpio_mmio`.
- 当地址落在 UART MMIO 区间时, 转发到 `uart_tx_mmio`.
- 当地址落在 SPI MMIO 区间时, 转发到 `spi_master_mmio`.
- 读数据从被命中的设备返回给 core.
- `ready` 表示当前访问完成. MMIO 直接为 1, RAM 和 SDRAM 访问会等待对应模块完成.

当前 RAM 从 `0x0000_8000` 开始译码. bus 会把传给 RAM 的地址减去 `0x0000_8000`, 所以 `simple_dual_port_ram` 内部仍然使用从 0 开始的本地地址. GPIO 和 UART 使用更小的 MMIO 窗口.

| 地址范围 | 目标 | 说明 |
| --- | --- | --- |
| `0x0000_0000` - `0x0000_7fff` | ROM | 取指直连 `simple_rom`, data bus 可只读访问常量 |
| `0x0000_8000` - `0x0000_ffff` | RAM | data bus 访问, 也支持从这里取指 |
| `0x0100_0000` - `0x0100_00ff` | GPIO MMIO | LEDR, SW, KEY, HEX, GPIO_0, GPIO_1 |
| `0x0100_0100` - `0x0100_01ff` | UART MMIO | UART TX |
| `0x0100_0200` - `0x0100_02ff` | SPI MMIO | 外接 SPI SD 模块基础传输 |
| `0x0200_0000` - `0x05ff_ffff` | SDRAM | DE1-SoC FPGA 侧 64 MiB SDRAM |
| 其他地址 | none | 读返回 0, 写无效果 |

SDRAM 细节见 `docs/dev/soc/sdram.md`.

### `gpio_mmio`

`gpio_mmio` 是 GPIO 外设寄存器块.

bus 只做大范围译码, 设备内部再判断精确寄存器窗口. 当前 GPIO 只响应 `0x0100_0000` - `0x0100_00ff` 内部窗口.

| 地址 | 名称 | 方向 | 有效位 | 作用 |
| --- | --- | --- | --- | --- |
| `0x0100_0000` | `LEDR` | R/W | `[9:0]` | 控制 10 个红色 LED |
| `0x0100_0004` | `SW` | R | `[9:0]` | 读取 10 个拨码开关 |
| `0x0100_0008` | `KEY` | R | `[3:0]` | 读取 4 个按键 |
| `0x0100_000c` | `HEX_LOW` | R/W | 4 bytes, 每 byte 低 7 bit | 控制 HEX0 到 HEX3 |
| `0x0100_0010` | `HEX_HIGH` | R/W | 低 2 bytes, 每 byte 低 7 bit | 控制 HEX4 到 HEX5 |
| `0x0100_0020` | `GPIO0_IN_LOW` | R | `[31:0]` | 读取 GPIO_0 低 32 bit |
| `0x0100_0024` | `GPIO0_IN_HIGH` | R | `[3:0]` | 读取 GPIO_0 高 4 bit |
| `0x0100_0028` | `GPIO0_OUT_LOW` | R/W | `[31:0]` | 设置 GPIO_0 输出值低 32 bit |
| `0x0100_002c` | `GPIO0_OUT_HIGH` | R/W | `[3:0]` | 设置 GPIO_0 输出值高 4 bit |
| `0x0100_0030` | `GPIO0_OE_LOW` | R/W | `[31:0]` | 设置 GPIO_0 输出使能低 32 bit |
| `0x0100_0034` | `GPIO0_OE_HIGH` | R/W | `[3:0]` | 设置 GPIO_0 输出使能高 4 bit |
| `0x0100_0040` | `GPIO1_IN_LOW` | R | `[31:0]` | 读取 GPIO_1 低 32 bit |
| `0x0100_0044` | `GPIO1_IN_HIGH` | R | `[3:0]` | 读取 GPIO_1 高 4 bit |
| `0x0100_0048` | `GPIO1_OUT_LOW` | R/W | `[31:0]` | 设置 GPIO_1 输出值低 32 bit |
| `0x0100_004c` | `GPIO1_OUT_HIGH` | R/W | `[3:0]` | 设置 GPIO_1 输出值高 4 bit |
| `0x0100_0050` | `GPIO1_OE_LOW` | R/W | `[31:0]` | 设置 GPIO_1 输出使能低 32 bit |
| `0x0100_0054` | `GPIO1_OE_HIGH` | R/W | `[3:0]` | 设置 GPIO_1 输出使能高 4 bit |

HEX 寄存器按 byte 拆分. 例如 `HEX_LOW` 中:

- `wdata[6:0]` 写入 `hex0`.
- `wdata[14:8]` 写入 `hex1`.
- `wdata[22:16]` 写入 `hex2`.
- `wdata[30:24]` 写入 `hex3`.

每个 HEX 端口只有 7 bit 段选, 因此每个 byte 的 bit 7 暂时保留. 当前段选默认按低电平点亮理解, reset 后输出 `7'h7f`.

GPIO_0 和 GPIO_1 每组在 Verilog 中暴露 `36 bit` FPGA IO:

- `IN` 寄存器只反映外部输入.
- `OUT` 寄存器保存输出值.
- `OE` 寄存器保存输出使能, `1` 表示 FPGA 驱动该 bit, `0` 表示该 bit 保持高阻输入.

DE1-SoC 的 GPIO 排针一般叫 40 pin, 但其中包含 VCC 和 GND. 当前 QSF 只约束到 FPGA 的 `gpio0[35:0]` 和 `gpio1[35:0]`, 所以 SoC 接口也保持 `36 bit`.

### `uart_tx_mmio`

`uart_tx_mmio` 是 UART TX 的寄存器块. 当前只支持发送, 不支持接收.

| 地址 | 名称 | 方向 | 有效位 | 作用 |
| --- | --- | --- | --- | --- |
| `0x0100_0100` | `UART_TXDATA` | R/W | `[7:0]` | 写入一个待发送字节, 读回最近写入的字节 |
| `0x0100_0104` | `UART_STATUS` | R | bit 0, bit 1 | bit 0 是 `tx_ready`, bit 1 是 `tx_busy` |

软件写 `UART_TXDATA` 前应该先读 `UART_STATUS`. 当 `tx_ready` 为 1 时写入低 8 bit, 硬件会发送一个字节. 如果 UART 正忙, 当前第一版会忽略这次写入.

默认 `UART_CLKS_PER_BIT` 是 434. 在 50 MHz 时钟下, 这个值接近 115200 baud.

### `uart_tx`

`uart_tx` 把 `uart_tx_mmio` 产生的 `tx_valid` 和 `tx_data` 转成串口 TX 波形.

- 空闲时输出 1.
- 发送 1 个 start bit, 值为 0.
- 发送 8 个 data bit, 低位先发.
- 发送 1 个 stop bit, 值为 1.

### `spi_master_mmio`

`spi_master_mmio` 是基础 SPI master 外设, 当前用于给外接 SPI SD 模块提供底层字节传输.

| 地址 | 名称 | 方向 | 有效位 | 作用 |
| --- | --- | --- | --- | --- |
| `0x0100_0200` | `SPI_TXDATA` | R/W | `[7:0]` | 写入一个字节并启动一次传输 |
| `0x0100_0204` | `SPI_RXDATA` | R | `[7:0]` | 读取最近一次收到的字节 |
| `0x0100_0208` | `SPI_STATUS` | R | bit 0, bit 1 | bit 0 是 ready, bit 1 是 busy |
| `0x0100_020c` | `SPI_CTRL` | R/W | bit 0 | `CS_N` 输出值 |
| `0x0100_0210` | `SPI_DIV` | R/W | `[15:0]` | `SCLK` 半周期分频 |

当前只支持 SPI mode 0, 8 bit, MSB first. SD 卡命令, FAT, `init.bin` 加载由后续 bootloader 软件实现.

更多说明见 `docs/dev/soc/spi.md` 和 `docs/dev/soc/sdcard.md`.

### `rv32i_soc`

`rv32i_soc` 是通用 SoC 顶层, 不直接绑定某个开发板的管脚名.

内部实例化:

- `rv32i_core`
- `simple_rom`
- `simple_bus`
- `simple_dual_port_ram`
- `gpio_mmio`
- `uart_tx_mmio`
- `uart_tx`
- `spi_master_mmio`

对外接口:

- `clk`
- `rst_n`
- `sw[9:0]`
- `key[3:0]`
- `ledr[9:0]`
- `hex0` 到 `hex5`
- `gpio0_in[35:0]`
- `gpio0_out[35:0]`
- `gpio0_oe[35:0]`
- `gpio1_in[35:0]`
- `gpio1_out[35:0]`
- `gpio1_oe[35:0]`
- `uart_tx_pin`
- `spi_miso`
- `spi_sclk`
- `spi_mosi`
- `spi_cs_n`

如果只想快速上板, 可以直接把 `rv32i_soc` 当 Quartus top, 然后在 QSF 中把这些端口映射到真实管脚. 但长期建议保留一个板级 top.

### `de1_soc_top`

`de1_soc_top` 是 DE1-SoC 板级 wrapper.

- 负责接收板级时钟, 按键, 开关, LED, HEX 端口.
- 内部只实例化 `rv32i_soc`.
- 当前用 `sw[9]` 作为板级复位, SW9=1 时复位, SW9=0 时运行.
- `key[3:0]` 同时传给 SoC 的 GPIO KEY 输入.
- 负责把 `gpio0_out` 和 `gpio0_oe` 转成 `gpio0` 三态端口.
- 负责把 `gpio1_out` 和 `gpio1_oe` 转成 `gpio1` 三态端口.
- 当前把 `gpio1[0]` 固定作为 UART TX 输出.
- 当前把 `gpio1[1]` 到 `gpio1[4]` 固定作为外接 SPI SD 模块端口.

这种写法的优点是 SoC 逻辑保持通用, 板级端口名, reset 来源, 后续 PLL, reset sync, SDRAM 引脚都可以放在 wrapper 层.

需要注意的是, 如果使用现有 QSF, 端口名字必须和 top module 一致. 例如 QSF 中写的是 `CLOCK_50`, 但 Verilog top 端口叫 `clk`, 那么 QSF 也要约束到 `clk`, 或者把 wrapper 端口改名为 `CLOCK_50`.

当前项目的 `riscv_soc.qsf` 约束到 `de1_soc_top` 的小写端口名. 板载 HEX 端口为 HEX0 到 HEX5, 每个端口都是 `[6:0]`, 没有 `dp` 或 8 bit 段选. 当前 SoC 的 HEX MMIO 仍然按每个 digit 占 8 bit 排布, 但 bit 7 只是保留位, 不会连接到小数点.

UART TX 没有额外新增顶层 pin 名称, 而是在 `de1_soc_top` 中复用 `gpio1[0]`. 如果要外接 USB-TTL, TTL 模块的 RX 接 GPIO_1[0], GND 和 DE1-SoC 共地. 因为这个 bit 已经被 UART 占用, 板级 top 中 `gpio1[0]` 不再作为普通 GPIO 输出使用.

当前没有直接使用板载 UART 口, 因为它属于 HPS 侧资源. 如果后续希望把 UART 作为稳定的板外调试口, 可能需要独立的 UART 转发芯片, 比如 USB-TTL 转换器, 这样 FPGA 侧的 `gpio1[0]` 就能直接输出串口波形.

SPI 也没有直接使用板载 J11 microSD, 因为它属于 HPS 侧 SD/MMC 接口. FPGA 侧当前通过 GPIO_1 外接 SPI SD 模块:

| 信号 | 用途 |
| --- | --- |
| `gpio1[1]` | SPI SCLK |
| `gpio1[2]` | SPI MOSI |
| `gpio1[3]` | SPI CS_N |
| `gpio1[4]` | SPI MISO |

## 开发步骤

已经完成的阶段:

1. 编写 `src/soc/simple_rom.v`.
2. 编写 `src/soc/simple_ram.v`.
3. 编写 `src/soc/simple_bus.v`.
4. 编写 `src/soc/gpio_mmio.v`.
5. 编写 `src/soc/rv32i_soc.v`.
6. 编写 SoC 和 MMIO 相关 testbench.
7. 编写 `src/de1_soc_top.v`.
8. 编写 `src/soc/uart_tx_mmio.v` 和 `src/soc/uart_tx.v`.
9. 编写 `src/soc/spi_master_mmio.v`.

当前下一步建议:

1. 编写最小 SD bootloader, 从 ROM 启动.
2. bootloader 通过 `spi_master_mmio` 初始化外接 SPI SD 模块.
3. 从 SD 卡读取 `init.bin`, `init.bin` 使用原始 binary 格式.
4. 把 `init.bin` 拷贝到 RAM 或 SDRAM.
5. 跳转到 RAM 或 SDRAM 执行.

## 测试边界

SoC 级测试不需要重新覆盖所有 RV32I 指令. Core 级测试已经覆盖主数据通路, SoC 级测试重点确认模块边界:

- ROM 能给 core 提供指令.
- core 的数据访问能进入 bus.
- RAM 读写能通过 bus 返回给 core.
- GPIO MMIO, UART TX MMIO, SPI MMIO 和 SDRAM 能被 load/store 访问.
- 板级 wrapper 的 reset 和端口连接没有明显反接.

## SDRAM 当前状态

SDRAM 已经作为 data bus 上的独立大窗口接入, 不替换低地址 `simple_dual_port_ram`.

原因是 SDRAM 访问通常是多周期的. SDRAM 还有初始化, 刷新, 行列地址和等待周期.

当前 data memory bus 使用以下信号:

- `req`
- `we`
- `be`
- `addr`
- `wdata`
- `rdata`
- `ready`

CPU 看到的是统一 memory bus, 不直接关心底层是 simple RAM, SDRAM, UART, 还是 MMIO.

后续路线:

1. 编写上板 SDRAM 自检程序.
2. 用 Quartus 检查 `dram_clk` 相关 timing.
3. 如果 50 MHz 稳定, 再考虑 PLL 到 100 MHz.
4. 让 bootloader 把 `init.bin` 搬到 SDRAM.
5. 再考虑从 SDRAM 取指.

更多细节见 `docs/dev/soc/sdram.md`.
