# SoC 开发说明

这个目录记录 CPU 外围封装的设计思路. 当前阶段已经从最小 ROM/RAM SoC 推进到带 data bus, GPIO MMIO 和 UART TX 的小系统.

## 当前边界

当前 SoC 负责连接 CPU, 指令 ROM, 数据 RAM, 数据总线, GPIO MMIO, UART TX.

- CPU 使用 `rv32i_core`.
- 指令从 `simple_rom` 读取, 暂时不走 data bus.
- 数据读写从 core 发出, 先进入 `simple_bus`.
- `simple_bus` 按地址窗口选择 RAM, GPIO MMIO 或 UART TX MMIO.
- `gpio_mmio` 提供 LEDR, SW, KEY, HEX0..HEX5, GPIO_0, GPIO_1 的寄存器访问.
- `uart_tx_mmio` 提供 UART TX 寄存器访问.
- `uart_tx` 负责产生 UART TX 串口波形.
- 暂时没有 UART RX, timer, interrupt, SDRAM.
- 暂时没有 `ready`/`valid` 等多周期握手.

这一阶段的目标是让 CPU 能通过普通 load/store 指令访问片上 RAM 和基础板载外设.

## 总体结构

```text
rv32i_core
  imem_addr  -> simple_rom.addr
  imem_rdata <- simple_rom.rdata

  dmem_*     -> simple_bus
                   -> simple_ram
                   -> gpio_mmio
                   -> uart_tx_mmio -> uart_tx
```

当前仍然是 Harvard 结构. 取指接口独立连接 ROM, 数据接口连接 bus. 这样可以先避免取指和访存之间的仲裁问题.

## 模块分工

### `simple_rom`

`simple_rom` 是只读指令存储器.

- 输入 `addr`, 来自 CPU 的 `imem_addr`.
- 输出 `rdata`, 返回当前 PC 对应的 32 位指令.
- `addr` 是字节地址.
- RV32I 指令固定 4 字节, 所以可用 `addr[31:2]` 选择第几条指令.
- ROM 内容通过 `$readmemh` 从 hex 文件初始化.
- 默认 `ROM_FILE` 是 `firmware/board_demo/board_demo.hex`.
- `ROM_WORDS` 决定可访问的 word 数, 超出范围时返回 `32'h0000_0013`.

固件源文件是 `firmware/board_demo/board_demo.S`. 运行 `just firmware-board-demo` 会重新生成 `firmware/board_demo/board_demo.hex`.

UART 实机测试固件是 `firmware/uart_demo/uart_demo.S`. 运行 `just firmware-uart-demo` 会生成 `firmware/uart_demo/uart_demo.hex`.

`de1_soc_top` 默认使用 UART 实机测试固件. `rv32i_soc` 默认仍使用 `board_demo.hex`, 方便本地仿真保持快速自检.

`firmware/test/simple_rom.hex` 只给 `simple_rom_vlg_tst` 使用, 不作为上板程序.

当前上板自检固件的行为:

- 运行 ALU, branch, RAM load/store, MMIO read/write 的最小自检.
- 全部通过时 `LEDR[3:0]` 显示 `1111`, `HEX0` 显示 `0`, `HEX1` 到 `HEX5` 熄灭.
- 失败时 `LEDR` 显示错误码, `HEX0` 显示错误码.

这样上板后可以不用串口, 直接通过 LED 和 HEX 判断 ROM 取指, CPU 执行, RAM 访问和 MMIO 访问是否跑通.

### `simple_ram`

`simple_ram` 是数据存储器.

- 输入 `req`, 表示 CPU 发起数据访问.
- 输入 `we`, 表示写访问.
- 输入 `be`, 表示字节写使能.
- 输入 `addr`, 表示字节地址.
- 输入 `wdata`, 表示写数据.
- 输出 `rdata`, 表示读数据.

第一版 RAM 使用组合读, 同步写. 这样可以匹配当前 `rv32i_core` 对 load 数据当周期可见的假设.

写入时按 `be` 分字节更新 32 位 word. 这样 `SB`, `SH`, `SW` 都可以共用同一个 RAM 模块.

### `simple_bus`

`simple_bus` 是当前的数据访问译码器.

- 接收 core 的 `dmem_req`, `dmem_we`, `dmem_be`, `dmem_addr`, `dmem_wdata`.
- 当地址落在 RAM 区间时, 转发到 `simple_ram`.
- 当地址落在 GPIO MMIO 区间时, 转发到 `gpio_mmio`.
- 当地址落在 UART MMIO 区间时, 转发到 `uart_tx_mmio`.
- 读数据从被命中的设备返回给 core.
- 当前 `clk` 预留给后续同步总线, 仲裁, SDRAM 或等待状态.

当前 RAM 译码只看 `addr[31:24]`. GPIO 和 UART 使用更小的 MMIO 窗口.

| 地址范围 | 目标 | 说明 |
| --- | --- | --- |
| `0x0000_0000` - `0x00ff_ffff` | RAM | 当前实际 RAM 只有 256 words |
| `0x0100_0000` - `0x0100_00ff` | GPIO MMIO | LEDR, SW, KEY, HEX, GPIO_0, GPIO_1 |
| `0x0100_0100` - `0x0100_01ff` | UART MMIO | UART TX |
| 其他地址 | none | 读返回 0, 写无效果 |

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

### `rv32i_soc`

`rv32i_soc` 是通用 SoC 顶层, 不直接绑定某个开发板的管脚名.

内部实例化:

- `rv32i_core`
- `simple_rom`
- `simple_bus`
- `simple_ram`
- `gpio_mmio`
- `uart_tx_mmio`
- `uart_tx`

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

这种写法的优点是 SoC 逻辑保持通用, 板级端口名, reset 来源, 后续 PLL, reset sync, SDRAM 引脚都可以放在 wrapper 层.

需要注意的是, 如果使用现有 QSF, 端口名字必须和 top module 一致. 例如 QSF 中写的是 `CLOCK_50`, 但 Verilog top 端口叫 `clk`, 那么 QSF 也要约束到 `clk`, 或者把 wrapper 端口改名为 `CLOCK_50`.

当前项目的 `riscv_soc.qsf` 约束到 `de1_soc_top` 的小写端口名. 板载 HEX 端口为 HEX0 到 HEX5, 每个端口都是 `[6:0]`, 没有 `dp` 或 8 bit 段选. 当前 SoC 的 HEX MMIO 仍然按每个 digit 占 8 bit 排布, 但 bit 7 只是保留位, 不会连接到小数点.

UART TX 没有额外新增顶层 pin 名称, 而是在 `de1_soc_top` 中复用 `gpio1[0]`. 如果要外接 USB-TTL, TTL 模块的 RX 接 GPIO_1[0], GND 和 DE1-SoC 共地. 因为这个 bit 已经被 UART 占用, 板级 top 中 `gpio1[0]` 不再作为普通 GPIO 输出使用.

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

当前下一步建议:

1. 修改 `firmware/board_demo/board_demo.S`.
2. 运行 `just firmware-board-demo`, 重新生成 `firmware/board_demo/board_demo.hex`.
3. 运行 `just test-simple-rom`, `just test-rv32i-soc`, `just test-de1-soc-top`.
4. 在 Quartus 中重新编译并上板观察 ROM demo 的效果.

## 测试边界

SoC 级测试不需要重新覆盖所有 RV32I 指令. Core 级测试已经覆盖主数据通路, SoC 级测试重点确认模块边界:

- ROM 能给 core 提供指令.
- core 的数据访问能进入 bus.
- RAM 读写能通过 bus 返回给 core.
- GPIO MMIO 和 UART TX MMIO 能被 load/store 访问.
- 板级 wrapper 的 reset 和端口连接没有明显反接.

## SDRAM 接入规划

未来可以接入 SDRAM, 但不能直接把 `simple_ram` 换成 SDRAM 控制器.

原因是当前 `rv32i_core` 假设 memory 数据很快可用, 而 SDRAM 访问通常是多周期的. SDRAM 还有初始化, 刷新, 行列地址和等待周期.

因此后续需要引入带等待的 memory bus. 建议信号如下:

- `req`
- `we`
- `be`
- `addr`
- `wdata`
- `rdata`
- `ready`

CPU 看到的是统一 memory bus, 不直接关心底层是 simple RAM, SDRAM, UART, 还是 MMIO.

推荐 SDRAM 路线:

1. 保留 ROM 取指, SDRAM 只做数据内存.
2. 给 data memory 访问增加 `ready` 和 core stall.
3. 接入 SDRAM controller.
4. 再考虑指令和数据都放在 SDRAM 中.

这样当前 `simple_rom`, `simple_ram`, `simple_bus`, `gpio_mmio`, `rv32i_soc` 不会浪费. 它们既是本地仿真的简单模型, 也是后续总线接口设计的参考.
