# C 裸机程序

这个页面记录当前 SoC 上运行 C 程序的最小流程. 目标不是做完整 C 运行时, 而是让一个简单 `main.c` 能访问 MMIO, 并通过 UART TX 输出字符.

## 文件结构

- `firmware/include/rv32i_soc.h`: SoC 寄存器头文件, 类似单片机项目里的寄存器定义头文件.
- `firmware/c_demo/startup.S`: 启动代码, 设置 `sp`, 清空 `.bss`, 然后调用 `main`.
- `firmware/c_demo/linker.ld`: 链接脚本, 指定 ROM 和 RAM 的地址范围.
- `firmware/c_demo/main.c`: C 示例程序.
- `firmware/c_demo/c_demo.hex`: 给 `simple_rom` 使用的 ROM 镜像.
- `apps/board_app/main.c`: 给 bootloader 加载的上板观察程序.
- `apps/linker.ld`: SD 启动程序链接脚本, 程序入口放在 `0x0201_0000`.
- `build/apps/board_app/board_app.bin`: 按 SD 启动地址链接的应用 raw binary.

## 地址布局

当前 C demo 使用这个内存布局:

| 区域 | 起始地址 | 大小 | 用途 |
| --- | --- | --- | --- |
| ROM | `0x0000_0000` | `8K` | `.text` 和 `.rodata` |
| RAM | `0x0000_f000` | `4K` | `.data`, `.bss`, stack |

`simple_rom` 的默认容量是 2048 words, 也就是 8 KiB. 取指仍然直连 ROM. data bus 也可以只读访问 `0x0000_0000` 到 `0x0000_7fff`, 这样 C 字符串常量放在 `.rodata` 后, `lbu` 可以正常把字符读出来.

SD 启动程序使用这个内存布局:

| 区域 | 起始地址 | 大小 | 用途 |
| --- | --- | --- | --- |
| SDRAM | `0x0201_0000` | `1M` | `.text`, `.rodata`, `.data`, `.bss`, stack |

bootloader 会把 `INIT.BIN` 从 SD 卡拷贝到 `0x0201_0000`, 然后跳到这个地址执行. 因此 SD 启动程序必须使用 `apps/linker.ld` 链接, 不能直接复用 ROM 地址的 `firmware/c_demo/linker.ld`.

## 头文件

`rv32i_soc.h` 里主要做两件事:

- 定义 `LEDR`, `SW`, `KEY`, `HEX_LOW`, `HEX_HIGH`, `UART_TXDATA`, `UART_STATUS`.
- 提供简单函数, 例如 `rv32i_led_write`, `rv32i_key_read`, `rv32i_uart_putc`, `rv32i_uart_puts`.

这些函数都是 `static inline`, 不依赖标准库. C 程序里只需要:

```c
#include "rv32i_soc.h"
```

## 编译命令

生成 C demo:

```shell
just firmware-c-demo
```

它会生成:

- `build/firmware/c_demo/c_demo.elf`: 带符号的 ELF 文件, 用于反汇编和检查.
- `build/firmware/c_demo/c_demo.bin`: 提取后的二进制镜像.
- `firmware/c_demo/c_demo.hex`: `simple_rom` 最终读取的 hex 文件.

`firmware/c_demo/c_demo.hex` 只包含实际固件 word. 如果 CPU 跑到 hex 未初始化的 ROM 区域, 读到的内容不作为稳定行为依赖.

生成可放入 SD 卡的 board app:

```shell
just build-app-board
```

它会生成:

- `build/apps/board_app/board_app.elf`: 按 `0x0201_0000` 链接的 ELF 文件.
- `build/apps/board_app/board_app.bin`: 应用 raw binary.

当前 `board_app.bin` 来自 `apps/board_app/main.c`. 它不是 hex 文件, 不能给 `$readmemh` 直接使用. 上板时把它复制到 FAT32 SD 卡根目录, 文件名改成 `INIT.BIN`.

这类 app 支持带初始值的全局变量. 原因是 app 的 `.text`, `.rodata`, `.data` 都在 SDRAM 地址空间里, bootloader 会把整个 binary 直接加载到 `0x0201_0000`. `.bss` 仍然由 `startup.S` 清零.

生成软浮点测试程序:

```shell
just build-app-soft-float-test
```

这个测试允许 C 代码使用 `float`, 但 CPU 不实现 F 扩展. Zig 链接时会带上 compiler-rt builtins, 例如 `__addsf3`, `__mulsf3`, `__fixsfsi`, 这些函数内部只使用整数指令完成单精度浮点运算. 链接时需要配合 `--gc-sections`, 否则没有用到的运行时代码会让镜像变大.

## 参数含义

`zig cc` 用来把 C 编译成 RISC-V 目标文件:

- `-target riscv32-freestanding`: 目标是 32 位 RISC-V 裸机环境, 没有操作系统.
- `-mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf`: 从 baseline_rv32 关闭当前 CPU 未实现的扩展, 最终只保留 RV32I.
- `-mabi=ilp32`: 使用 RV32 常见 ABI, `int`, `long`, pointer 都是 32 bit.
- `-ffreestanding`: 告诉编译器这是裸机程序.
- `-fno-builtin`: 不把普通函数名替换成编译器内建函数.
- `-fno-pic -fno-pie`: 不生成位置无关代码.
- `-fno-stack-protector`: 不生成栈保护代码, 避免依赖额外运行时符号.

`riscv64-elf-as` 用来汇编 `startup.S`, 并用 `-march=rv32i -mabi=ilp32` 明确限制启动代码只使用 RV32I.

`zig cc` 负责链接 C 目标文件和 `startup.o`, 并使用 `linker.ld` 把入口固定到 `_start`. 这样 Zig 会自动带上 compiler-rt 中的整数和浮点软件 helper, 例如 `__mulsi3`, `__divsi3`, `__addsf3`.

`riscv64-elf-objcopy` 只提取 `.text` 和 `.rodata`, 因为 ROM 镜像只需要代码和只读常量.

`xxd -e -g 4 -c 4` 把 little-endian 二进制按 32-bit word 转成 `$readmemh` 能读取的格式.

## 当前限制

- 支持 `.bss` 清零.
- 支持 stack, ROM C demo 栈顶是 `0x0001_0000`, SD app 栈顶是 `0x0211_0000`.
- 直接放进 ROM 的 `firmware-c-demo` 暂时不支持带初始值的全局变量, 因为还没有从 ROM 复制 `.data` 到 RAM 的启动逻辑.
- 通过 SD 启动的 app binary 支持 initialized `.data`.
- 支持软浮点 helper, 但不支持硬件 F/D 浮点指令.
- 暂时没有 `malloc`, `printf`, 中断和系统调用.
- C 编译后必须检查不能出现 RVC, M, CSR, A/F/D 等当前 CPU 不支持的指令.

可以用下面命令检查:

```shell
riscv64-elf-readelf -h build/firmware/c_demo/c_demo.elf
riscv64-elf-objdump -d build/firmware/c_demo/c_demo.elf
```

如果 `Flags` 里出现 `RVC`, 或反汇编地址出现 `0x2` 这种半字步进, 就说明混入了压缩指令, 当前 CPU 不能运行.

## 上板现象

如果使用 `firmware/c_demo/c_demo.hex` 直接作为 ROM:

复位释放后:

- `LEDR[0]` 亮起.
- UART 发送 `C demo\n`.
- KEY 状态改变时, UART 发送 `Kx\n`, 其中 `x` 是 KEY 低 4 bit 的十六进制值.
- KEY 状态改变后, `LEDR[1:0]` 显示 `11`.

如果使用 `de1_soc_top` 默认配置, ROM 里先运行 bootloader. bootloader 通过 SPI SD 模块读取 FAT32 根目录的 `INIT.BIN`, 再跳到 RAM 执行.

如果使用 bootloader 加载当前 `board_app`:

- UART 先输出 `init app\n`.
- LEDR[0] 表示 app 已启动.
- LEDR[9] 周期闪烁, 表示主循环仍在运行.
- LEDR[8:2] 跟随 SW[6:0].
- HEX 显示 `KEY event count` 和 SW 低 10 bit.
- KEY[3:0] 状态变化时, LEDR[1] 翻转, UART 输出 `Kx yy\n`.
