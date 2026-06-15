# SoC 开发说明

这个目录记录 CPU 外围封装的设计思路. 当前阶段已经从最小 ROM/RAM SoC 推进到带 data bus 和 GPIO MMIO 的小系统.

## 当前边界

当前 SoC 负责连接 CPU, 指令 ROM, 数据 RAM, 数据总线, GPIO MMIO.

- CPU 使用 `rv32i_core`.
- 指令从 `simple_rom` 读取, 暂时不走 data bus.
- 数据读写从 core 发出, 先进入 `simple_bus`.
- `simple_bus` 按地址高位选择 RAM 或 GPIO MMIO.
- `gpio_mmio` 提供 LEDR, SW, KEY, HEX0..HEX7 的寄存器访问.
- 暂时没有 UART, timer, interrupt, SDRAM.
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
```

当前仍然是 Harvard 结构. 取指接口独立连接 ROM, 数据接口连接 bus. 这样可以先避免取指和访存之间的仲裁问题.

## 模块分工

### `simple_rom`

`simple_rom` 是只读指令存储器.

- 输入 `addr`, 来自 CPU 的 `imem_addr`.
- 输出 `rdata`, 返回当前 PC 对应的 32 位指令.
- `addr` 是字节地址.
- RV32I 指令固定 4 字节, 所以可用 `addr[31:2]` 选择第几条指令.
- 第一版可以用 `case` 写死小程序.
- 默认指令建议返回 `32'h0000_0013`, 也就是 `addi x0, x0, 0`.

后续有固件构建流程后, 再把写死指令替换为 `$readmemh`.

当前 ROM 已经放入一个上板 demo:

- 初始化 HEX0 到 HEX7, 让数码管显示固定内容.
- 循环读取 SW, 并把 `SW[9:0]` 镜像到 `LEDR[9:0]`.

这样上板后只要拨动开关, 就能直接看到 LED 变化. 数码管则用于确认 ROM 取指和 MMIO 写入都已经跑通.

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
- 当地址落在 MMIO 区间时, 转发到 `gpio_mmio`.
- 读数据从被命中的设备返回给 core.
- 当前 `clk` 预留给后续同步总线, 仲裁, SDRAM 或等待状态.

当前译码比较粗, 只看 `addr[31:24]`.

| 地址范围 | 目标 | 说明 |
| --- | --- | --- |
| `0x0000_0000` - `0x00ff_ffff` | RAM | 当前实际 RAM 只有 256 words |
| `0x0100_0000` - `0x01ff_ffff` | MMIO | 先转发给 GPIO MMIO |
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
| `0x0100_0010` | `HEX_HIGH` | R/W | 4 bytes, 每 byte 低 7 bit | 控制 HEX4 到 HEX7 |

HEX 寄存器按 byte 拆分. 例如 `HEX_LOW` 中:

- `wdata[6:0]` 写入 `hex0`.
- `wdata[14:8]` 写入 `hex1`.
- `wdata[22:16]` 写入 `hex2`.
- `wdata[30:24]` 写入 `hex3`.

每个 HEX 端口只有 7 bit 段选, 因此每个 byte 的 bit 7 暂时保留. 当前段选默认按低电平点亮理解, reset 后输出 `7'h7f`.

### `rv32i_soc`

`rv32i_soc` 是通用 SoC 顶层, 不直接绑定某个开发板的管脚名.

内部实例化:

- `rv32i_core`
- `simple_rom`
- `simple_bus`
- `simple_ram`
- `gpio_mmio`

对外接口:

- `clk`
- `rst_n`
- `sw[9:0]`
- `key[3:0]`
- `ledr[9:0]`
- `hex0` 到 `hex7`

如果只想快速上板, 可以直接把 `rv32i_soc` 当 Quartus top, 然后在 QSF 中把这些端口映射到真实管脚. 但长期建议保留一个板级 top.

### `de1_soc_top`

`de1_soc_top` 是 DE1-SoC 板级 wrapper.

- 负责接收板级时钟, 按键, 开关, LED, HEX 端口.
- 内部只实例化 `rv32i_soc`.
- 当前用 `key[0]` 作为 `rst_n`.
- `key[3:0]` 同时传给 SoC 的 GPIO KEY 输入.

这种写法的优点是 SoC 逻辑保持通用, 板级端口名, reset 来源, 后续 PLL, reset sync, SDRAM 引脚都可以放在 wrapper 层.

需要注意的是, 如果使用现有 QSF, 端口名字必须和 top module 一致. 例如 QSF 中写的是 `CLOCK_50`, 但 Verilog top 端口叫 `clk`, 那么 QSF 也要约束到 `clk`, 或者把 wrapper 端口改名为 `CLOCK_50`.

当前项目的 `riscv_soc.qsf` 约束到 `de1_soc_top` 的小写端口名. 参考 DE1-SoC SDRAM 工程只提供 HEX0 到 HEX5 的板载管脚, `Selfsale` 工程也只有 HEX0 到 HEX5. `Selfsale` 中的 `cs[3:0]` 是 virtual pin, 不能当作真实位选管脚参考. 因此 `hex6` 和 `hex7` 暂时作为 virtual pin. 如果后续接外部 8 位数码管, 需要把 `hex6` 和 `hex7` 改成实际 GPIO 管脚.

这两个参考工程的数码管端口都是 `[6:0]`, 没有 `dp` 或 8 bit 段选. 当前 SoC 的 HEX MMIO 仍然按每个 digit 占 8 bit 排布, 但 bit 7 只是保留位, 不会连接到小数点.

## 开发步骤

已经完成的阶段:

1. 编写 `src/soc/simple_rom.v`.
2. 编写 `src/soc/simple_ram.v`.
3. 编写 `src/soc/simple_bus.v`.
4. 编写 `src/soc/gpio_mmio.v`.
5. 编写 `src/soc/rv32i_soc.v`.
6. 编写 SoC 和 MMIO 相关 testbench.
7. 编写 `src/de1_soc_top.v`.

当前下一步建议:

1. 给 `de1_soc_top` 增加很小的 wrapper 测试.
2. 准备上板用 QSF, 先只映射时钟, KEY, SW, LEDR, HEX.
3. 观察当前 ROM demo 的上板效果, 确认 LED 镜像和 HEX 显示都正常.
4. 再考虑把 ROM 改为 `$readmemh`, 建立软件构建流程.

## 测试边界

SoC 级测试不需要重新覆盖所有 RV32I 指令. Core 级测试已经覆盖主数据通路, SoC 级测试重点确认模块边界:

- ROM 能给 core 提供指令.
- core 的数据访问能进入 bus.
- RAM 读写能通过 bus 返回给 core.
- GPIO MMIO 能被 load/store 访问.
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
