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

## 当前结构

```text
rv32i_core
  dmem_* + dmem_ready
    -> simple_bus
        -> simple_dual_port_ram
        -> gpio_mmio
        -> uart_tx_mmio
        -> spi_master_mmio
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

SDRAM 是多周期设备, 不能像 `simple_ram` 一样组合读. 因此 `rv32i_core` 增加了 `dmem_ready`.

当 `dmem_req=1` 且 `dmem_ready=0` 时:

- `pc_reg` 保持当前 PC.
- `regfile` 不写回.
- 当前 load/store 指令继续停在同一个周期语义上等待.

普通 ROM/RAM/MMIO 访问在 `simple_bus` 中仍然直接返回 `ready=1`. 只有 SDRAM 窗口会等待控制器完成.

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

## 后续

当前 SDRAM 已经可以作为 data bus 的大容量窗口. 更完整的方向:

1. 写一个上板 SDRAM 自检程序, 用 LED/UART 显示 pass/fail.
2. 用 Quartus 编译并检查 `dram_clk` 相关 timing.
3. 如果 50 MHz 稳定, 再考虑 PLL 提升到 100 MHz.
4. 后续让 bootloader 把 SD 卡中的程序搬到 SDRAM.
5. 再考虑从 SDRAM 取指, 这需要 instruction bus 也支持等待或 cache.
