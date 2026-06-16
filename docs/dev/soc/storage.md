# 存储布局

这个文档只记录当前 SoC 的存储地址和启动链路. 细节模块说明仍然看对应文档, 例如 `sdram.md`, `sdcard.md`, `bootloader.md`.

## 总体地址图

CPU 看到的是 32-bit 字节地址. 当前主要地址窗口如下:

| 地址范围 | 大小 | 目标 | 主要用途 |
| --- | --- | --- | --- |
| `0x0000_0000` - `0x0000_7fff` | 32 KiB window | `simple_rom` | reset 后取指, bootloader 或 ROM demo |
| `0x0000_f000` - `0x0000_ffff` | 4 KiB | `onchip_dual_port_ram` | bootloader `.bss`, sector buffer, stack |
| `0x0100_0000` - `0x0100_00ff` | 256 B | GPIO MMIO | LEDR, SW, KEY, HEX, GPIO_0, GPIO_1 |
| `0x0100_0100` - `0x0100_01ff` | 256 B | UART MMIO | UART TX |
| `0x0100_0200` - `0x0100_02ff` | 256 B | SPI MMIO | 外接 SPI SD 模块 |
| `0x0200_0000` - `0x05ff_ffff` | 64 MiB | SDRAM | app 执行区, framebuffer, 大块数据 |

这里的 ROM 地址窗口是总线译码窗口. 当前 `simple_rom.v` 默认实例容量是 `2048 words`, 也就是 8 KiB. `firmware/bootloader/linker.ld` 当前也按 8 KiB 限制 bootloader. 如果后续 bootloader 变大, 需要同步调整 ROM 模块参数, linker 和测试.

## 取指路径

`rv32i_soc` 里取指没有经过 `simple_bus`, 而是单独按 PC 地址选择来源:

| PC 范围 | 取指来源 |
| --- | --- |
| `< 0x0000_8000` | `simple_rom` |
| `0x0000_f000` - `0x0000_ffff` | `onchip_dual_port_ram` imem 口 |
| `0x0200_0000` - `0x05ff_ffff` | SDRAM 取指口 |
| 其他地址 | 返回 `nop` |

这样做是为了让 ROM, boot RAM, SDRAM app 都能被 CPU 当作指令来源. SDRAM 取指是多周期访问, 当前有一个单 word cache, 用来避免等待期间反复发起同一个 PC 的 SDRAM 请求.

## 数据访问路径

load/store 从 `rv32i_core` 的 data memory 口出来, 进入 `simple_bus`. `simple_bus` 按地址转发到 ROM, onchip RAM, MMIO 或 SDRAM.

| 地址范围 | data bus 行为 |
| --- | --- |
| `0x0000_0000` - `0x0000_7fff` | 只读 ROM, 用于读取 `.rodata` 常量 |
| `0x0000_f000` - `0x0000_ffff` | 读写 onchip RAM |
| `0x0100_0000` - `0x0100_02ff` | 读写 MMIO 外设 |
| `0x0200_0000` - `0x05ff_ffff` | 读写 SDRAM |
| 其他地址 | 读返回 0, 写无效果 |

ROM 和 MMIO 当前可以直接 `ready=1`. onchip RAM 和 SDRAM 是同步或多周期设备, 需要等待对应 `ready`.

## simple_rom

`simple_rom` 是 reset 后最先执行的存储器. 它通过 `$readmemh` 加载 hex 文件.

当前常见 ROM 镜像:

| 文件 | 用途 |
| --- | --- |
| `firmware/bootloader/bootloader.hex` | 上板默认启动镜像, 从 SD 卡加载 `INIT.BIN` |
| `firmware/board_demo/board_demo.hex` | 不依赖 SD 卡的板级自检 |
| `firmware/uart_demo/uart_demo.hex` | UART TX 实机测试 |
| `firmware/c_demo/c_demo.hex` | 直接放入 ROM 的 C demo |
| `firmware/selfsale/selfsale.hex` | 直接放入 ROM 的 selfsale 演示 |

ROM hex 是给硬件初始化使用的文本格式, 不是 SD 卡上运行的程序格式. SD 卡应用使用 raw binary, 文件名是 `INIT.BIN`.

直接放进 ROM 的 C 程序目前不支持 initialized `.data`, 因为启动代码没有做 "从 ROM 拷贝 `.data` 到 RAM" 这一步. 这类程序应避免带初值的全局可写变量.

## onchip RAM

当前 onchip RAM 只保留 4 KiB:

```text
0x0000_f000 - 0x0000_ffff
```

它的作用是给 bootloader 提供最小运行环境:

| 内容 | 位置 | 说明 |
| --- | --- | --- |
| `.bss` | onchip RAM 低处 | `sector[512]` 和 FAT32 解析变量 |
| stack | onchip RAM 高处 | `_stack_top = 0x0001_0000`, 向下增长 |
| `.data` | 当前基本不用 | bootloader linker 会拒绝 initialized `.data` |

Quartus 上板路径使用 `onchip_ram` IP, 通过 `onchip_dual_port_ram` 适配项目里的 data 口和 imem 口. 这样可以明确使用 M10K, 避免把 RAM 展开成大量寄存器.

## SDRAM

SDRAM 是当前大内存区:

```text
0x0200_0000 - 0x05ff_ffff
```

当前约定:

| 地址范围 | 用途 |
| --- | --- |
| `0x0200_0000` 起 | VGA framebuffer, `160 x 120 x 8-bit`, 约 19200 bytes |
| `0x0201_0000` - `0x0210_ffff` | app 默认加载和执行区, 1 MiB |
| `0x0211_0000` | app 默认 `_stack_top` |
| `0x0211_0000` 之后 | 预留给后续更大的 heap, buffer, 文件缓存等 |

普通应用使用 `apps/linker.ld`, 链接地址从 `0x0201_0000` 开始:

```text
0x0201_0000  _start
              .text
              .rodata
              .data
              .bss
...
0x0211_0000  _stack_top
```

app 支持 initialized `.data`. 原因是 `.text`, `.rodata`, `.data` 都在 SDRAM 运行地址内, `objcopy` 会把这些段直接放进 app binary. bootloader 把整个 binary 拷贝到 `0x0201_0000` 后, `.data` 初值已经在正确位置. `.bss` 不在 binary 中, 由 app 自己的 `startup.S` 清零.

## SD 卡

SD 卡不是 CPU memory map 的一部分. CPU 不能像访问 RAM 一样直接 load/store SD 卡内容. 当前 SD 卡通过外接 SPI 模块访问:

```text
CPU load/store -> SPI MMIO -> SPI wires -> SD card
```

bootloader 在 ROM 中运行, 通过 SPI 初始化 SD 卡, 解析 FAT32, 在根目录查找短文件名 `INIT.BIN`, 再把文件内容复制到 SDRAM.

SD 卡中的 `INIT.BIN` 是 raw binary:

| 文件类型 | 放置位置 | 作用 |
| --- | --- | --- |
| `bootloader.hex` | FPGA ROM 初始化 | reset 后第一段程序 |
| `INIT.BIN` | FAT32 SD 卡根目录 | bootloader 加载到 SDRAM 的 app |

不要把 hex 文件直接改名成 `INIT.BIN`. `INIT.BIN` 应该来自 `riscv64-elf-objcopy -O binary` 生成的 `.bin`.

## 启动链路

默认上板链路如下:

```text
reset
  -> PC = 0x0000_0000
  -> simple_rom 返回 bootloader 指令
  -> bootloader 设置 sp = 0x0001_0000
  -> bootloader 清空 onchip RAM 中的 `.bss`
  -> bootloader 初始化 SPI SD 卡
  -> bootloader 解析 FAT32
  -> bootloader 查找 `INIT.BIN`
  -> bootloader 把 `INIT.BIN` 复制到 0x0201_0000
  -> bootloader 跳转到 0x0201_0000
  -> app 从 SDRAM 取指执行
```

app 启动后会重新设置自己的 stack:

```text
sp = 0x0211_0000
```

从这个时刻开始, bootloader 的 onchip RAM 临时数据不再重要. app 的代码, 常量, 全局变量, bss 和 stack 都按 SDRAM 地址空间运行.

## 构建产物和放置关系

| 命令 | 产物 | 放置方式 |
| --- | --- | --- |
| `just firmware-bootloader` | `firmware/bootloader/bootloader.hex` | Quartus ROM 初始化 |
| `just firmware-board-demo` | `firmware/board_demo/board_demo.hex` | 可作为 ROM demo |
| `just build-app-board` | `build/apps/board_app/board_app.bin` | 复制到 SD 卡根目录并命名为 `INIT.BIN` |
| `just build-app-sdram-test` | `build/apps/sdram_test/sdram_test.bin` | 复制到 SD 卡根目录并命名为 `INIT.BIN` |
| `just build-app-vga-test` | `build/apps/vga_test/vga_test.bin` | 复制到 SD 卡根目录并命名为 `INIT.BIN` |
| `just build-app-snake` | `build/apps/snake/snake.bin` | 复制到 SD 卡根目录并命名为 `INIT.BIN` |

## 当前边界

- ROM 默认实际容量按 8 KiB 使用.
- bootloader 的 onchip RAM 只有 4 KiB.
- bootloader 当前最大加载 1 MiB app.
- SDRAM 起始区域被 VGA framebuffer 使用.
- SD 卡只支持 FAT32 根目录短文件名 `INIT.BIN`.
- 当前没有 cache coherence 问题, 因为 CPU 和 VGA 共享 SDRAM 时只通过仲裁器访问.

## 后续扩展规则

如果后续要调整存储布局, 优先保持这几个原则:

1. `0x0000_0000` 继续作为 reset ROM, 保持启动简单.
2. onchip RAM 只放启动阶段必须的小数据, 不承载普通 app.
3. SDRAM 承载 app 和大块数据.
4. SD 卡继续作为块设备, 不进入 CPU 直接寻址空间.
5. 修改地址后同步更新 Verilog localparam, linker script, `firmware/include/rv32i_soc.h`, 文档和相关 testbench.
