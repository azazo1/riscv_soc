# UART 发送流程

本文档记录当前 SoC 中 UART TX 的数据流和软件使用方式.

## 模块边界

当前 UART 只支持 TX, 不支持 RX.

相关模块:

- `uart_tx_mmio`: 提供 CPU 可访问的 MMIO 寄存器.
- `uart_tx`: 把一个字节转成 UART TX 波形.
- `simple_bus`: 把 UART 地址窗口转发到 `uart_tx_mmio`.
- `rv32i_soc`: 连接 `uart_tx_mmio` 和 `uart_tx`.
- `de1_soc_top`: 把 `uart_tx_pin` 接到 `gpio1[0]`.

当前串口格式固定为 8N1:

- 8 data bits.
- no parity.
- 1 stop bit.

波特率通过 `CLKS_PER_BIT` 静态设置. 在 50 MHz 时钟和 115200 baud 下, `CLKS_PER_BIT = 50000000 / 115200`, 约等于 434.

## MMIO 寄存器

UART 地址窗口是 `0x0100_0100` 到 `0x0100_01ff`.

| 地址 | 名称 | 方向 | 作用 |
| --- | --- | --- | --- |
| `0x0100_0100` | `UART_TXDATA` | R/W | 写低 8 bit 后发送一个字节, 读回最近写入的字节 |
| `0x0100_0104` | `UART_STATUS` | R | bit 0 是 `tx_ready`, bit 1 是 `tx_busy` |

`tx_ready = 1` 表示发送器空闲, 可以接收下一个字节.

`tx_busy = 1` 表示发送器正在输出 start bit, data bits 或 stop bit. 和 `tx_ready` 是完全相反的.

## 硬件发送流程

CPU 写入 `UART_TXDATA` 时, 数据会按下面路径流动:

```text
rv32i_core store
  -> simple_bus
  -> uart_tx_mmio
  -> tx_valid + tx_data
  -> uart_tx
  -> uart_tx_pin
  -> de1_soc_top.gpio1[0]
```

`uart_tx_mmio` 只在这些条件同时满足时接受写入:

- `req = 1`.
- `we = 1`.
- 地址命中 `UART_TXDATA`.
- `be[0] = 1`.
- `tx_ready = 1`.

接受写入后, `uart_tx_mmio` 会把 `wdata[7:0]` 放入 `tx_data`, 并让 `tx_valid` 拉高 1 个时钟周期.

`uart_tx` 在空闲状态看到 `tx_valid = 1` 后, 会锁存 `tx_data`, 然后开始发送:

1. 空闲状态输出 `1`.
2. start bit 输出 `0`.
3. 依次发送 bit 0 到 bit 7, 也就是低位先发.
4. stop bit 输出 `1`.
5. 回到空闲状态, `tx_ready` 重新变为 `1`.

每一位保持 `CLKS_PER_BIT` 个时钟周期.

## 软件写入流程

软件不能连续无条件写 `UART_TXDATA`. 正确方式是先轮询 `UART_STATUS`.

推荐流程:

```text
loop:
  读取 UART_STATUS
  如果 bit 0 为 0, 继续等待
  如果 bit 0 为 1, 写 UART_TXDATA 的低 8 bit
```

用 C 风格伪代码表示:

```c
#define UART_TXDATA  (*(volatile unsigned int *)0x01000100)
#define UART_STATUS  (*(volatile unsigned int *)0x01000104)

void uart_putc(unsigned char ch) {
    while ((UART_STATUS & 1) == 0) {
    }
    UART_TXDATA = ch;
}
```

## 如何防止发送中再次写入

当前硬件没有 FIFO, 也没有总线 stall. 因此保护方式是两层:

第一层是软件约定:

- 每次发送前先读 `UART_STATUS`.
- 只有 `tx_ready = 1` 才写 `UART_TXDATA`.

第二层是硬件过滤:

- `uart_tx_mmio` 只有在 `tx_ready = 1` 时才产生 `tx_valid`.
- 如果 UART 正忙, 写 `UART_TXDATA` 不会触发新的发送.

这意味着 busy 时写入不会覆盖正在发送的字节, 但这次写入也不会排队等待. 如果软件没有轮询状态就连续写多个字节, 后面的字节可能会被忽略.

后续如果希望软件可以连续写入, 需要在 `uart_tx_mmio` 和 `uart_tx` 之间增加 1 字节缓冲或 FIFO, 并在 `UART_STATUS` 中增加 buffer full 之类的状态位.
