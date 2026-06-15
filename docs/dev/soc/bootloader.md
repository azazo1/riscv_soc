# Bootloader 设计说明

bootloader 是 ROM 中的第一段程序. 它负责初始化外接 SPI SD 模块, 在 FAT32 根目录查找 `INIT.BIN`, 把文件加载到 RAM, 然后跳转执行.

## 文件分工

- `firmware/bootloader/startup.S`: 设置 `sp`, 清空 `.bss`, 调用 `main`.
- `firmware/bootloader/main.c`: 初始化 SD 卡, 解析 FAT32, 加载 `INIT.BIN`, 跳转到 RAM.
- `firmware/bootloader/linker.ld`: 指定 bootloader 的 ROM 和 RAM 布局.
- `firmware/bootloader/bootloader.hex`: 给 `$readmemh` 使用的 ROM 初始化文件.
- `firmware/init_app/linker.ld`: 把 SD 卡里的应用程序链接到 `0x0000_8000`.

## 运行流程

bootloader 由 `simple_rom` 从地址 `0x0000_0000` 开始执行.

1. LED 写入 `0x100`, UART 输出 `boot\n`.
2. SPI 先使用慢速分频, 拉高 CS_N 并发送 80 个空闲时钟.
3. 依次发送 `CMD0`, `CMD8`, `CMD55` + `ACMD41`, `CMD58`, 让 SD 卡进入 SPI 模式.
4. 读取 LBA 0, 如果有 MBR 分区表就取第一个分区起始 LBA.
5. 读取 FAT32 BPB, 解析 reserved sectors, FAT 数量, FAT 大小, root cluster.
6. 从 root cluster 开始扫描根目录, 查找短文件名 `INIT    BIN`.
7. 按 FAT cluster chain 读取文件内容, 拷贝到 `0x0000_8000`.
8. UART 输出 `jump\n`, LED 写入 `0x200`, 跳转到 `0x0000_8000`.

失败时会输出:

```text
boot fail <name> <code>
```

同时 LED 显示错误码并停在死循环.

## 内存布局

bootloader 自身在 ROM 中运行, 临时数据放在 RAM 高地址附近:

| 区域 | 起始地址 | 大小 | 用途 |
| --- | --- | --- | --- |
| ROM | `0x0000_0000` | `32 KiB` | bootloader `.text` 和 `.rodata` |
| APP | `0x0000_8000` | `28 KiB` | `INIT.BIN` 加载位置 |
| boot RAM | `0x0000_f000` | `4 KiB` | bootloader `.bss` 和 stack |

bootloader 的 sector buffer 是 `sector[512]`, 位于 `.bss`. 因为 bootloader 自己要继续读取 FAT 和文件内容, `INIT.BIN` 最大先限制为 `0x7000` bytes, 防止覆盖 `0x0000_f000` 之后的 bootloader 临时数据和 stack.

当前 bootloader 不支持 initialized `.data`. `linker.ld` 中保留了断言, 如果 bootloader C 代码里出现带初值的全局变量, 链接会失败.

## 加载后的地址视角

硬件地址映射:

| 地址范围 | 目标 |
| --- | --- |
| `0x0000_0000` - `0x0000_7fff` | ROM |
| `0x0000_8000` - `0x0000_ffff` | RAM |
| `0x0100_0000` - `0x0100_00ff` | GPIO MMIO |
| `0x0100_0100` - `0x0100_01ff` | UART MMIO |
| `0x0100_0200` - `0x0100_02ff` | SPI MMIO |

取指规则:

| PC 范围 | 取指来源 |
| --- | --- |
| `< 0x0000_8000` | ROM |
| `0x0000_8000` - `0x0000_ffff` | RAM |
| 其他地址 | NOP |

bootloader 运行时, RAM 的低 28 KiB 留给将要加载的 `INIT.BIN`, 高 4 KiB 给 bootloader 的 `.bss` 和 stack:

```text
0x0000_8000 - 0x0000_efff  INIT.BIN 加载区
0x0000_f000 - 0x0000_ffff  bootloader .bss 和 stack
```

`firmware-init-bin` 使用 `firmware/init_app/linker.ld`, 所以 `c_demo` 被作为 `init.bin` 构建时, 它的软件视角是:

```text
0x0000_8000  _start
              .text
              .rodata
              .data 当前仍要求为空
              .bss
0x0001_0000  _stack_top
```

MMIO 地址不会因为 bootloader 加载而改变:

```text
LEDR  0x0100_0000
SW    0x0100_0004
KEY   0x0100_0008
UART  0x0100_0100
SPI   0x0100_0200
```

`INIT.BIN` 启动后会重新设置自己的 `sp = 0x0001_0000`. 此时 bootloader 已经完成任务并跳走, 所以 `0x0000_f000` 到 `0x0000_ffff` 可以被应用程序作为 `.bss` 或 stack 使用. 当前设计默认 `INIT.BIN` 不返回.

## FAT32 支持范围

- SDHC/SDSC SPI mode 初始化.
- 单 sector 读取, 命令是 CMD17.
- sector 大小必须是 512 bytes.
- FAT32 根目录遍历.
- 只查找短文件名 `INIT.BIN`.
- 支持跨 cluster 文件链.
- `INIT.BIN` 最大 28 KiB.
- 不支持长文件名, 子目录, 写入, exFAT, FAT16.

## 构建和文件放置

生成 ROM 里的 bootloader:

```shell
just firmware-bootloader
```

输出文件:

```text
firmware/bootloader/bootloader.hex
```

生成 SD 卡根目录要放的应用程序:

```shell
just firmware-init-bin
```

输出文件:

```text
build/firmware/sdcard/init.bin
```

把 `build/firmware/sdcard/init.bin` 复制到 FAT32 SD 卡根目录, 文件名使用 `init.bin` 或 `INIT.BIN` 均可. 关键是 FAT32 目录项需要形成短文件名 `INIT    BIN`.

## 上板观察

串口参数沿用当前 UART TX 设置:

- 115200 baud.
- 8 data bits.
- no parity.
- 1 stop bit.

正常启动时能看到:

```text
boot
jump
```

如果只看到 `boot`, 通常说明 SD 初始化或 FAT32 读取阶段失败. 如果看到 `jump` 但后续程序没有输出, 重点检查 `INIT.BIN` 是否按 `0x0000_8000` 链接, 以及 `init_app` 的启动代码是否正确.

## 常见失败点

| 输出名 | 大致含义 |
| --- | --- |
| `cmd0` | SD 卡没有进入 idle 状态 |
| `cmd8` | SD 卡不接受 CMD8 |
| `cmd8-v` | CMD8 返回电压检查字段不符合预期 |
| `cmd8-p` | CMD8 返回 pattern 不符合预期 |
| `cmd55` | ACMD 前置命令失败 |
| `acmd41` | SD 卡初始化超时 |
| `cmd58` | OCR 读取失败 |
| `cmd17` | 单 sector 读取命令失败 |
| `token` | 等待数据 token `0xfe` 超时 |
| `mbr` | LBA 0 没有 `0x55aa` 签名 |
| `bps` | FAT32 sector 大小不是 512 bytes |
| `spc` | FAT32 sectors per cluster 为 0 |
| `cluster` | sectors per cluster 不是 2 的幂 |
| `fat32` | FAT32 关键字段不合理 |
| `init` | 根目录没有找到 `INIT.BIN` |
| `size` | `INIT.BIN` 为空或超过当前加载上限 |
| `chain` | FAT cluster chain 提前结束 |
| `ret` | `INIT.BIN` 程序返回到 bootloader |
