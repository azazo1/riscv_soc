# SPI 外设

`spi_master_mmio` 是一个很小的 SPI master 外设, 目标是先让 CPU 能通过 MMIO 控制外接 SPI SD 模块.

当前实现只负责最基础的字节传输:

- SPI mode 0, 空闲时 `SCLK=0`, 在上升沿采样 `MISO`.
- 每次传输 8 bit.
- MSB first.
- `CS_N` 由软件手动控制.
- `SCLK` 半周期分频可配置.

它暂时不负责 SD 协议, FAT 文件系统, DMA, interrupt. 后续读取 SD 卡中的 `init.bin` 应该由 ROM bootloader 软件完成.

## MMIO 寄存器

SPI 外设窗口是 `0x0100_0200` 到 `0x0100_02ff`.

| 地址 | 名称 | 方向 | 有效位 | 作用 |
| --- | --- | --- | --- | --- |
| `0x0100_0200` | `SPI_TXDATA` | R/W | `[7:0]` | 写入一个字节并启动一次传输, 读回最近写入的字节 |
| `0x0100_0204` | `SPI_RXDATA` | R | `[7:0]` | 读取最近一次传输收到的字节 |
| `0x0100_0208` | `SPI_STATUS` | R | bit 0, bit 1 | bit 0 是 `ready`, bit 1 是 `busy` |
| `0x0100_020c` | `SPI_CTRL` | R/W | bit 0 | `CS_N`, 写 0 选中外设, 写 1 取消选中 |
| `0x0100_0210` | `SPI_DIV` | R/W | `[15:0]` | `SCLK` 半周期分频, 写 0 会按 1 处理 |

`SPI_DIV` 的含义:

```text
SCLK = clk / (2 * SPI_DIV)
```

如果板上时钟是 50 MHz:

| `SPI_DIV` | 近似 `SCLK` | 用途 |
| --- | --- | --- |
| `63` | `397 kHz` | SD 卡初始化阶段可先用这个量级 |
| `25` | `1 MHz` | 初始化后可提高一点速度 |
| `5` | `5 MHz` | 后续确认时序稳定后再考虑 |

## 板级接线

`de1_soc_top` 当前把 GPIO_1 的低几位固定给 UART 和 SPI:

| DE1-SoC 信号 | 用途 | 外接 SPI SD 模块引脚 |
| --- | --- | --- |
| `gpio1[0]` | UART TX | 不接 SD |
| `gpio1[1]` | SPI SCLK | `CLK` 或 `SCK` |
| `gpio1[2]` | SPI MOSI | `DI` 或 `MOSI` |
| `gpio1[3]` | SPI CS_N | `CS` |
| `gpio1[4]` | SPI MISO | `DO` 或 `MISO` |
| `gpio1[5]` 到 `gpio1[35]` | 普通 GPIO | 不由 SPI 占用 |

外接模块还需要接 3.3 V 和 GND. 使用前需要确认模块信号电平是 3.3 V.

## 软件访问顺序

软件侧最小访问流程:

1. 写 `SPI_DIV`, 设置一个合适的分频值.
2. 写 `SPI_CTRL=0`, 拉低 `CS_N`.
3. 等待 `SPI_STATUS & SPI_READY` 非 0.
4. 写 `SPI_TXDATA`, 启动一次 8 bit 传输.
5. 等待 `SPI_STATUS & SPI_READY` 非 0.
6. 读 `SPI_RXDATA`, 得到收到的 8 bit.
7. 如果一次命令结束, 写 `SPI_CTRL=1`, 拉高 `CS_N`.

`firmware/include/rv32i_soc.h` 已经提供了这些基础 helper:

- `rv32i_spi_set_div`
- `rv32i_spi_set_cs`
- `rv32i_spi_transfer`

## 测试

当前测试覆盖两层:

- `just test-spi-master-mmio`: 直接测试 SPI 外设的寄存器, `SCLK`, `MOSI`, `MISO`, `CS_N`.
- `just test-rv32i-soc-mmio`: 通过 CPU 的 load/store 访问 SPI MMIO, 验证 CPU 到 bus 再到 SPI 外设的路径.
