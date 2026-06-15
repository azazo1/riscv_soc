# VGA 设计记录

## 当前边界

当前先把 VGA 放在 `src/soc/vga/` 中独立开发, 不直接接入 `simple_bus`, `rv32i_soc` 和板级 top.

这样做的原因是 SDRAM 接入会修改内存结构, VGA 后续如果要使用 framebuffer, 也会依赖内存结构. 先把 VGA 时序模块单独稳定下来, 可以减少两个方向同时修改同一批文件的问题.

## 模块划分

当前有两个基础模块.

- `vga_timing`: 产生 640x480@60Hz 的扫描坐标和同步信号.
- `vga_pattern`: 使用 `vga_timing` 的坐标输出彩条, 用于上板确认 VGA 引脚和显示器识别.

`vga_timing` 的输出含义如下.

| 信号 | 作用 |
| --- | --- |
| `x` | 当前扫描的横向计数 |
| `y` | 当前扫描的纵向计数 |
| `visible` | 当前是否处于 640x480 可见区 |
| `hsync` | VGA 行同步, 低有效 |
| `vsync` | VGA 场同步, 低有效 |

## 时序参数

640x480@60Hz 常用参数如下.

| 项目 | 数值 |
| --- | --- |
| 可见宽度 | 640 |
| 行前沿 | 16 |
| 行同步 | 96 |
| 行后沿 | 48 |
| 行总周期 | 800 |
| 可见高度 | 480 |
| 场前沿 | 10 |
| 场同步 | 2 |
| 场后沿 | 33 |
| 场总周期 | 525 |

像素时钟通常使用约 25.175 MHz. 实验中 25 MHz 一般也可以被多数显示器接受. 参考项目中的 VGA 设计也是使用 25 MHz 像素时钟, 行总周期 800, 场总周期 525, HS/VS 低有效.

## 后续接入顺序

建议按下面顺序推进.

1. 板级 top 接入 `vga_pattern`, 先看到固定彩条.
2. 给 VGA 增加 MMIO 控制寄存器, 例如背景色和使能位.
3. 增加小 framebuffer, 例如 160x120x8bit, 显示时放大到 640x480.
4. SDRAM 稳定后, 再把 framebuffer 放到 SDRAM 或增加 DMA/line FIFO.

不要一开始做 640x480x16bit 或 640x480x24bit framebuffer. 这类 framebuffer 容量较大, 更适合在 SDRAM 和读写仲裁稳定以后实现.

## 推荐 MMIO 草案

后续可以预留一个 MMIO 页面.

| 地址 | 名称 | 作用 |
| --- | --- | --- |
| `0x0100_0300` | `VGA_CTRL` | bit0 控制显示使能 |
| `0x0100_0304` | `VGA_BG_COLOR` | 24 bit 背景色 |
| `0x0100_0308` | `VGA_STATUS` | 当前状态 |

framebuffer 方案可以后续再定. 如果先做小 framebuffer, 可以使用单独 dual-port RAM, CPU 一侧写入, VGA 一侧按扫描坐标读取.

## SDRAM framebuffer

当前已经加入第一版 SDRAM framebuffer 显示路径.

| 项目 | 数值 |
| --- | --- |
| framebuffer 地址 | `0x0200_0000` |
| 逻辑分辨率 | `160x120` |
| 屏幕放大 | 每个逻辑像素放大成 `4x4` |
| 像素格式 | 8 bit RGB332 |
| 每个 word | 4 个像素, 低字节是靠左像素 |

硬件中 VGA 看到的是 SDRAM 窗口内部偏移 `0x0000_0000`, 软件中对应地址是 `RV32I_VGA_FB_BASE`.

第一版没有 line FIFO. VGA 会通过 `sdram_arbiter` 和 CPU 共享 SDRAM 控制器. 仲裁策略是 CPU 优先, VGA 空闲时读取 framebuffer. 这能用于上板可视测试, 但不是最终的视频架构. 后续如果要稳定显示动画或高分辨率图形, 应该增加 line FIFO 或 DMA 预取.

## 可视测试程序

源码:

```text
apps/vga_test/main.c
```

构建:

```shell
just build-app-vga-test
```

输出:

```text
build/apps/vga_test/vga_test.bin
```

上板时把 `vga_test.bin` 放到 FAT32 SD 卡根目录, 文件名改为 `INIT.BIN`. bootloader 会把程序加载到 `0x0201_0000` 后执行. 程序会向 SDRAM framebuffer 写入移动彩条, VGA 口显示放大后的 `160x120` 图像.

仿真:

```shell
just test-vga-sdram-fb
just test-rv32i-soc-vga-app
```

## 测试

当前模块级测试为 `vga_pattern_vlg_tst`.

测试重点:

- 可见区开始时 `blank_n` 为高.
- 消隐区 `blank_n` 为低.
- HS/VS 在指定同步区间为低.
- 彩条边界颜色正确.
- 一帧结束后坐标回到 `(0, 0)`.
