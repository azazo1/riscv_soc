## SD 卡接入方案

板载 J11 microSD 卡槽接到 HPS 的 SD/MMC 接口, 不是 FPGA fabric 能直接控制的普通 SPI 口.

依据是 DE1-SoC 手册 `3.7 Peripherals Connected to Hard Processor System (HPS)` 和 `3.7.5 Micro SD Card Socket`. 这一节把 microSD 放在 HPS 外设下面, 引脚也列为 `HPS_SD_CLK`, `HPS_SD_CMD`, `HPS_SD_DATA[0..3]`.

所以当前 FPGA 侧 RV32I SoC 不直接控制板载 J11 microSD. 第一版采用外接 SPI SD 模块, 通过 GPIO_1 暴露 `SCLK`, `MOSI`, `MISO`, `CS_N`.

如果后续要把程序从 SD 卡启动进来, 更稳妥的路线是:

1. 保留一个小 boot_rom, 先从 ROM 启动.
2. 由外接 SPI SD 模块配合 bootloader, 把镜像搬到 RAM 或 SDRAM.
3. 再跳转到 RAM 或 SDRAM 执行.

如果一定要用 J11, 就需要走 HPS 侧, 先由 HPS 访问 microSD, 再通过 HPS-to-FPGA bridge 写入 FPGA 侧存储器.

当前项目更推荐先把 external SPI SD 模块作为 FPGA 侧启动介质, 这样可以和现有的 `simple_bus`, `simple_dual_port_ram`, `bootloader` 直接协作. 板载 microSD 继续保留给后续 HPS 方案.

## init.bin 约定

SD 卡中的执行程序命名为 `init.bin`.

`init.bin` 是原始 binary 文件, 不是 hex 文件. 当前 `*.hex` 只用于 `$readmemh` 初始化 `simple_rom`, 不作为 SD 卡程序格式, 也就是说 `.hex` 用来当作 bootloader 启动.

当前 bootloader 会在 FAT32 根目录查找 `INIT.BIN`. 文件名可以在电脑上显示为 `init.bin`, 但 SD 卡目录项必须能形成短文件名 `INIT    BIN`.

bootloader 的任务是:

1. 初始化 SPI SD 卡.
2. 读取 MBR 或直接读取 FAT32 BPB.
3. 解析 FAT32 参数和根目录 cluster.
4. 查找根目录中的 `INIT.BIN`.
5. 把 `INIT.BIN` 拷贝到 `0x0000_8000`.
6. 跳转到 `0x0000_8000` 执行.

第一版 FAT32 支持范围:

- SDHC/SDSC SPI mode 初始化.
- 单 sector 读取, 命令是 CMD17.
- sector 大小必须是 512 bytes.
- FAT32 根目录遍历.
- 只查找短文件名 `INIT.BIN`.
- 支持跨 cluster 文件链.
- `INIT.BIN` 最大 28 KiB, 因为当前 RAM 从 `0x0000_8000` 到 `0x0000_ffff`.
- 不支持长文件名, 子目录, 写入, exFAT, FAT16.

## 和当前 ROM 的关系

`simple_rom` 仍然保留. 它的作用是放一个很小的启动程序:

- 当前阶段: 放上板 demo 或 C demo.
- SD 启动阶段: 放 bootloader.

bootloader 自身仍然可以用 hex 初始化到 ROM, 但它从 SD 卡读取的目标程序必须是 `init.bin` binary.

运行下面命令可以生成 ROM 里的 bootloader:

```shell
just firmware-bootloader
```

输出文件是:

```text
firmware/bootloader/bootloader.hex
```

运行下面命令可以先生成后续放入 SD 卡的二进制文件:

```shell
just build-app-board
```

输出文件是:

```text
build/firmware/sdcard/init.bin
```

把 `build/firmware/sdcard/init.bin` 复制到 FAT32 SD 卡根目录, 文件名使用 `init.bin` 或 `INIT.BIN` 均可.
