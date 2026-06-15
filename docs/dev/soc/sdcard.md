## SD 卡接入方案

板载 J11 microSD 卡槽接到 HPS 的 SD/MMC 接口, 不是 FPGA fabric 能直接控制的普通 SPI 口.

如果后续要把程序从 SD 卡启动进来, 更稳妥的路线是:

1. 保留一个小 boot_rom, 先从 ROM 启动.
2. 由 HPS/Linux, 或者外接 SPI SD 模块配合 bootloader, 把镜像搬到 RAM 或 SDRAM.
3. 再跳转到 RAM 或 SDRAM 执行.

如果一定要用 J11, 就需要走 HPS 侧, 先由 HPS 访问 microSD, 再通过 HPS-to-FPGA bridge 写入 FPGA 侧存储器.

当前项目更推荐先把 external SPI SD 模块作为 FPGA 侧启动介质, 这样可以和现有的 `simple_bus`, `simple_ram`, `bootloader` 直接协作. 板载 microSD 继续保留给后续 HPS 方案.
