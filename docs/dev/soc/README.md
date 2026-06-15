# SoC 开发说明

这个目录记录 CPU 外围封装的设计思路. 当前阶段先做最小 SoC, 目标是把已经能单独运行的 `rv32i_core` 接到正式的 ROM 和 RAM 模块上.

## 当前边界

第一版 SoC 只负责把 CPU, ROM, RAM 连接起来.

- CPU 仍然使用 `rv32i_core`.
- 指令从 `simple_rom` 读取.
- 数据读写走 `simple_ram`.
- 暂时不接 UART, LED, timer, SDRAM.
- 暂时不做复杂总线协议.

这一阶段的目标不是追求完整外设, 而是让 CPU 不再依赖 testbench 里的临时 instruction case 和 data_mem 数组.

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

### `simple_ram`

`simple_ram` 是数据存储器.

- 输入 `req`, 表示 CPU 发起数据访问.
- 输入 `we`, 表示写访问.
- 输入 `be`, 表示字节写使能.
- 输入 `addr`, 表示字节地址.
- 输入 `wdata`, 表示写数据.
- 输出 `rdata`, 表示读数据.

第一版 RAM 可以使用组合读, 同步写. 这样可以匹配当前 `rv32i_core` 对 load 数据当周期可见的假设.

写入时按 `be` 分字节更新 32 位 word. 这样 `SB`, `SH`, `SW` 都可以共用同一个 RAM 模块.

### `rv32i_soc`

`rv32i_soc` 是最小系统顶层.

内部实例化:

- `rv32i_core`
- `simple_rom`
- `simple_ram`

连接关系:

- `core.imem_addr -> rom.addr`
- `rom.rdata -> core.imem_rdata`
- `core.dmem_req -> ram.req`
- `core.dmem_we -> ram.we`
- `core.dmem_be -> ram.be`
- `core.dmem_addr -> ram.addr`
- `core.dmem_wdata -> ram.wdata`
- `ram.rdata -> core.dmem_rdata`

## 开发步骤

建议按下面顺序推进:

1. 编写 `src/soc/simple_rom.v`.
2. 编写 `src/soc/simple_ram.v`.
3. 编写 `src/soc/rv32i_soc.v`.
4. 编写 `rv32i_soc_vlg_tst`.
5. 增加 `test-rv32i-soc` recipe.
6. 只运行 `just test-rv32i-soc`, 验证最小 SoC 可以执行 ROM 中的小程序.

测试目标不需要重新覆盖所有 RV32I 指令. Core 级测试已经覆盖主数据通路, SoC 级测试重点确认模块边界和存储器连接正确.

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

这样当前 `simple_rom`, `simple_ram`, `rv32i_soc` 不会浪费. 它们既是本地仿真的简单模型, 也是后续总线接口设计的参考.
