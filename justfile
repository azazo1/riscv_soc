build_dir := "build"
verilog_sources := `find src -type f -name '*.v' ! -path 'src/soc/onchip_ram/*' ! -path 'src/soc/sdram/ref_ctrl/*' -print | sort | tr '\n' ' '`
selfsale_test_sources := "src/core/alu.v src/core/branch_unit.v src/core/decoder.v src/core/imm_gen.v src/core/load_store_unit.v src/core/next_pc_unit.v src/core/pc_reg.v src/core/regfile.v src/core/rv32i_core.v src/soc/gpio_mmio.v src/soc/onchip_dual_port_ram.v src/soc/rv32i_soc.v src/soc/simple_bus.v src/soc/simple_rom.v src/soc/spi_master_mmio.v src/soc/sdram/sdram_arbiter.v src/soc/sdram/sdram_ctrl_wrapper.v src/soc/sdram/sdram_simple_ctrl.v src/soc/sdram/sdram_model.v src/soc/uart_tx.v src/soc/uart_tx_mmio.v src/soc/vga/vga_sdram_fb.v src/soc/vga/vga_timing.v src/soc/rv32i_soc_selfsale_rom_vlg_tst.v"

default:
    @just --list

build-verilog-with top +sources:
    @mkdir -p {{ build_dir }}/{{ top }}
    @verilator -I./src -I./src/soc --binary --top-module {{ top }} --Mdir {{ build_dir }}/{{ top }} {{ sources }}

run-verilog-with top +sources:
    @just build-verilog-with {{ top }} {{ sources }}
    @./{{ build_dir }}/{{ top }}/V{{ top }}

build-verilog top:
    @just build-verilog-with {{ top }} {{ verilog_sources }}

run-verilog top:
    @just run-verilog-with {{ top }} {{ verilog_sources }}

firmware: firmware-board-demo firmware-uart-demo firmware-bootloader firmware-selfsale

firmware-board-demo:
    @mkdir -p {{ build_dir }}/firmware/board_demo
    @# -march=rv32i 限制汇编器只生成当前 CPU 已实现的 RV32I 指令.
    @# -mabi=ilp32 匹配 32 位整数寄存器和 RV32 的基础 ABI, ilp 分别表示 int long pointer, 32 表示目标环境 32 位.
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/firmware/board_demo/board_demo.o firmware/board_demo/board_demo.S
    @# elf32lriscv 生成 32 位 little-endian RISC-V ELF
    @# -Ttext=0x00000000: 把 .text 放在地址 0 的位置.
    @# -e _start: 告诉连接器这个程序从 _start 这个标签开始执行
    riscv64-elf-ld -m elf32lriscv -Ttext=0x00000000 -e _start -o {{ build_dir }}/firmware/board_demo/board_demo.elf {{ build_dir }}/firmware/board_demo/board_demo.o
    @# ROM 只需要 .text 指令段, 不把 ELF 头或符号表写进镜像.
    riscv64-elf-objcopy -O binary -j .text {{ build_dir }}/firmware/board_demo/board_demo.elf {{ build_dir }}/firmware/board_demo/board_demo.bin
    @# bin-to-rom-hex 只写入实际固件 word, 不额外填充 ROM 空间.
    @just bin-to-rom-hex {{ build_dir }}/firmware/board_demo/board_demo.bin firmware/board_demo/board_demo.hex

firmware-uart-demo:
    @mkdir -p {{ build_dir }}/firmware/uart_demo
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/firmware/uart_demo/uart_demo.o firmware/uart_demo/uart_demo.S
    riscv64-elf-ld -m elf32lriscv -Ttext=0x00000000 -e _start -o {{ build_dir }}/firmware/uart_demo/uart_demo.elf {{ build_dir }}/firmware/uart_demo/uart_demo.o
    riscv64-elf-objcopy -O binary -j .text {{ build_dir }}/firmware/uart_demo/uart_demo.elf {{ build_dir }}/firmware/uart_demo/uart_demo.bin
    @just bin-to-rom-hex {{ build_dir }}/firmware/uart_demo/uart_demo.bin firmware/uart_demo/uart_demo.hex

firmware-c-demo:
    @mkdir -p {{ build_dir }}/firmware/c_demo
    @# zig cc 负责编译 RV32 C 代码, freestanding 表示没有宿主系统和标准库.
    @# baseline_rv32 默认会打开不少扩展, 后面的 -m-a-f-d-c-zicsr... 用来收紧到当前 CPU 支持的 RV32I.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -I firmware/include -c -o {{ build_dir }}/firmware/c_demo/main.o firmware/c_demo/main.c
    @# startup.S 用 GNU as 汇编, 明确限制为 RV32I.
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/firmware/c_demo/startup.o firmware/c_demo/startup.S
    @# linker.ld 固定 ROM=0x0000_0000, RAM=0x0000_f000, 并提供 _stack_top 等启动符号.
    @# 用 zig cc 链接, 让 compiler-rt 提供 __mulsi3, __divsi3 等软件整数 helper.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,firmware/c_demo/linker.ld -Wl,--gc-sections -o {{ build_dir }}/firmware/c_demo/c_demo.elf {{ build_dir }}/firmware/c_demo/startup.o {{ build_dir }}/firmware/c_demo/main.o
    @# C 程序需要 .text 和 .rodata, 因为字符串常量放在 .rodata.
    riscv64-elf-objcopy -O binary -j .text -j .rodata {{ build_dir }}/firmware/c_demo/c_demo.elf {{ build_dir }}/firmware/c_demo/c_demo.bin
    @just bin-to-rom-hex {{ build_dir }}/firmware/c_demo/c_demo.bin firmware/c_demo/c_demo.hex
    @riscv64-elf-size {{ build_dir }}/firmware/c_demo/c_demo.elf

firmware-bootloader:
    @mkdir -p {{ build_dir }}/firmware/bootloader
    @# bootloader 放进 ROM 从 0x0000_0000 启动, 运行后读取 SD 根目录的 INIT.BIN.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -I firmware/include -c -o {{ build_dir }}/firmware/bootloader/main.o firmware/bootloader/main.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/firmware/bootloader/startup.o firmware/bootloader/startup.S
    @# linker.ld 把 bootloader 代码放在 ROM, 把 sector buffer 和 stack 放在 0x0000_f000 附近.
    @# 用 zig cc 链接, 让 compiler-rt 提供 __mulsi3, __divsi3 等软件整数 helper.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,firmware/bootloader/linker.ld -Wl,--gc-sections -o {{ build_dir }}/firmware/bootloader/bootloader.elf {{ build_dir }}/firmware/bootloader/startup.o {{ build_dir }}/firmware/bootloader/main.o
    riscv64-elf-objcopy -O binary -j .text -j .rodata {{ build_dir }}/firmware/bootloader/bootloader.elf {{ build_dir }}/firmware/bootloader/bootloader.bin
    @just bin-to-rom-hex {{ build_dir }}/firmware/bootloader/bootloader.bin firmware/bootloader/bootloader.hex
    @riscv64-elf-size {{ build_dir }}/firmware/bootloader/bootloader.elf

firmware-selfsale:
    @mkdir -p {{ build_dir }}/firmware/selfsale
    @# selfsale 是直接放进 ROM 的演示固件, 不经过 bootloader, 也不访问 SDRAM.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -I firmware/include -c -o {{ build_dir }}/firmware/selfsale/main.o firmware/selfsale/main.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/firmware/selfsale/startup.o firmware/c_demo/startup.S
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,firmware/selfsale/linker.ld -Wl,--gc-sections -o {{ build_dir }}/firmware/selfsale/selfsale.elf {{ build_dir }}/firmware/selfsale/startup.o {{ build_dir }}/firmware/selfsale/main.o
    riscv64-elf-objcopy -O binary -j .text -j .rodata {{ build_dir }}/firmware/selfsale/selfsale.elf {{ build_dir }}/firmware/selfsale/selfsale.bin
    @just bin-to-rom-hex {{ build_dir }}/firmware/selfsale/selfsale.bin firmware/selfsale/selfsale.hex
    @riscv64-elf-size {{ build_dir }}/firmware/selfsale/selfsale.elf

build-selfsale-test-image:
    @mkdir -p {{ build_dir }}/tests/selfsale
    @# 仿真版只把按键轮询延时调短, 逻辑和上板固件相同.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -DSELFSALE_DELAY_TICKS=8 -I firmware/include -c -o {{ build_dir }}/tests/selfsale/main.o firmware/selfsale/main.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/tests/selfsale/startup.o firmware/c_demo/startup.S
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,firmware/selfsale/linker.ld -Wl,--gc-sections -o {{ build_dir }}/tests/selfsale/selfsale.elf {{ build_dir }}/tests/selfsale/startup.o {{ build_dir }}/tests/selfsale/main.o
    riscv64-elf-objcopy -O binary -j .text -j .rodata {{ build_dir }}/tests/selfsale/selfsale.elf {{ build_dir }}/tests/selfsale/selfsale.bin
    @just bin-to-rom-hex {{ build_dir }}/tests/selfsale/selfsale.bin {{ build_dir }}/tests/selfsale/selfsale.hex
    @riscv64-elf-size {{ build_dir }}/tests/selfsale/selfsale.elf

build-app-board:
    @mkdir -p {{ build_dir }}/apps/board_app
    @# board_app.bin 是普通应用镜像, 入口地址按 0x0201_0000 链接到 SDRAM.
    @# 上板时再把选中的 .bin 文件放到 SD 卡根目录并命名为 INIT.BIN.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -I firmware/include -c -o {{ build_dir }}/apps/board_app/main.o apps/board_app/main.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/apps/board_app/startup.o firmware/c_demo/startup.S
    @# 用 zig cc 链接, 让 compiler-rt 提供 __mulsi3, __divsi3 等软件整数 helper.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,apps/linker.ld -Wl,--gc-sections -o {{ build_dir }}/apps/board_app/board_app.elf {{ build_dir }}/apps/board_app/startup.o {{ build_dir }}/apps/board_app/main.o
    @# app 整体在 SDRAM 中运行, 所以 .data 初值可以直接放进 .bin.
    riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data {{ build_dir }}/apps/board_app/board_app.elf {{ build_dir }}/apps/board_app/board_app.bin
    @riscv64-elf-size {{ build_dir }}/apps/board_app/board_app.elf

build-app-sdram-test:
    @mkdir -p {{ build_dir }}/apps/sdram_test
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -I firmware/include -c -o {{ build_dir }}/apps/sdram_test/main.o apps/sdram_test/main.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/apps/sdram_test/startup.o firmware/c_demo/startup.S
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,apps/linker.ld -Wl,--gc-sections -o {{ build_dir }}/apps/sdram_test/sdram_test.elf {{ build_dir }}/apps/sdram_test/startup.o {{ build_dir }}/apps/sdram_test/main.o
    riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data {{ build_dir }}/apps/sdram_test/sdram_test.elf {{ build_dir }}/apps/sdram_test/sdram_test.bin
    @riscv64-elf-size {{ build_dir }}/apps/sdram_test/sdram_test.elf

build-app-sdram-test-image: build-app-sdram-test
    @mkdir -p {{ build_dir }}/tests/sdram_app
    @just bin-to-rom-hex {{ build_dir }}/apps/sdram_test/sdram_test.bin {{ build_dir }}/tests/sdram_app/sdram_test.hex

build-app-vga-test:
    @mkdir -p {{ build_dir }}/apps/vga_test
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -I firmware/include -c -o {{ build_dir }}/apps/vga_test/main.o apps/vga_test/main.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/apps/vga_test/startup.o firmware/c_demo/startup.S
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,apps/linker.ld -Wl,--gc-sections -o {{ build_dir }}/apps/vga_test/vga_test.elf {{ build_dir }}/apps/vga_test/startup.o {{ build_dir }}/apps/vga_test/main.o
    riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data {{ build_dir }}/apps/vga_test/vga_test.elf {{ build_dir }}/apps/vga_test/vga_test.bin
    @riscv64-elf-size {{ build_dir }}/apps/vga_test/vga_test.elf

build-app-vga-test-image: build-app-vga-test
    @mkdir -p {{ build_dir }}/tests/vga_app
    @just bin-to-rom-hex {{ build_dir }}/apps/vga_test/vga_test.bin {{ build_dir }}/tests/vga_app/vga_test.hex

build-app-snake:
    @mkdir -p {{ build_dir }}/apps/snake
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -I firmware/include -c -o {{ build_dir }}/apps/snake/main.o apps/snake/main.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/apps/snake/startup.o firmware/c_demo/startup.S
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,apps/linker.ld -Wl,--gc-sections -o {{ build_dir }}/apps/snake/snake.elf {{ build_dir }}/apps/snake/startup.o {{ build_dir }}/apps/snake/main.o
    riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data {{ build_dir }}/apps/snake/snake.elf {{ build_dir }}/apps/snake/snake.bin
    @riscv64-elf-size {{ build_dir }}/apps/snake/snake.elf

build-app-snake-image: build-app-snake
    @mkdir -p {{ build_dir }}/tests/snake_app
    @just bin-to-rom-hex {{ build_dir }}/apps/snake/snake.bin {{ build_dir }}/tests/snake_app/snake.hex

build-app-init-data-test:
    @mkdir -p {{ build_dir }}/tests/init_data_test
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -I firmware/include -c -o {{ build_dir }}/tests/init_data_test/main.o apps/init_data_test/main.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/tests/init_data_test/startup.o firmware/c_demo/startup.S
    @# 用 zig cc 链接, 让 compiler-rt 提供 __mulsi3, __divsi3 等软件整数 helper.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,apps/linker.ld -Wl,--gc-sections -o {{ build_dir }}/tests/init_data_test/init_data_test.elf {{ build_dir }}/tests/init_data_test/startup.o {{ build_dir }}/tests/init_data_test/main.o
    riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data {{ build_dir }}/tests/init_data_test/init_data_test.elf {{ build_dir }}/tests/init_data_test/init_data_test.bin
    @just bin-to-rom-hex {{ build_dir }}/tests/init_data_test/init_data_test.bin {{ build_dir }}/tests/init_data_test/init_data_test.hex
    @riscv64-elf-size {{ build_dir }}/tests/init_data_test/init_data_test.elf

build-app-soft-float-test:
    @mkdir -p {{ build_dir }}/tests/soft_float_test
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -ffunction-sections -fdata-sections -I firmware/include -c -o {{ build_dir }}/tests/soft_float_test/main.o apps/soft_float_test/main.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/tests/soft_float_test/startup.o firmware/c_demo/startup.S
    @# 用 zig cc 链接, 让 Zig 自动带上 compiler-rt builtins, 例如 __addsf3, __mulsf3.
    @# --gc-sections 会丢弃没有用到的 helper, 否则软浮点运行时会明显变大.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -ffunction-sections -fdata-sections -Wl,--gc-sections -Wl,-T,apps/linker.ld -o {{ build_dir }}/tests/soft_float_test/soft_float_test.elf {{ build_dir }}/tests/soft_float_test/startup.o {{ build_dir }}/tests/soft_float_test/main.o
    riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data {{ build_dir }}/tests/soft_float_test/soft_float_test.elf {{ build_dir }}/tests/soft_float_test/soft_float_test.bin
    @just bin-to-rom-hex {{ build_dir }}/tests/soft_float_test/soft_float_test.bin {{ build_dir }}/tests/soft_float_test/soft_float_test.hex
    @riscv64-elf-size {{ build_dir }}/tests/soft_float_test/soft_float_test.elf

bin-to-rom-hex input output:
    @# xxd -e -g 4 -c 4 把 little-endian 字节按 32-bit word 输出给 $readmemh.
    @xxd -e -g 4 -c 4 {{ input }} | awk '{ print $2 }' > {{ output }}

test: test-regfile test-alu test-imm-gen test-decoder test-branch-unit test-load-store-unit test-pc-reg test-next-pc-unit test-rv32i-core test-simple-rom test-simple-dual-port-ram test-onchip-dual-port-ram test-simple-bus test-gpio-mmio test-uart-tx test-uart-tx-mmio test-spi-master-mmio test-sdram-simple-ctrl test-sdram-ctrl-wrapper test-vga-sdram-fb test-rv32i-soc test-rv32i-soc-mmio test-rv32i-soc-ram-exec test-rv32i-soc-bootloader-stack test-rv32i-soc-init-data test-rv32i-soc-soft-float test-rv32i-soc-sdram-app test-rv32i-soc-vga-app test-rv32i-soc-snake-app test-rv32i-soc-uart-rom test-rv32i-soc-c-rom test-rv32i-soc-selfsale-rom test-de1-soc-top

test-regfile:
    @just run-verilog regfile_vlg_tst

test-alu:
    @just run-verilog alu_vlg_tst

test-imm-gen:
    @just run-verilog imm_gen_vlg_tst

test-decoder:
    @just run-verilog decoder_vlg_tst

test-branch-unit:
    @just run-verilog branch_unit_vlg_tst

test-load-store-unit:
    @just run-verilog load_store_unit_vlg_tst

test-pc-reg:
    @just run-verilog pc_reg_vlg_tst

test-next-pc-unit:
    @just run-verilog next_pc_unit_vlg_tst

test-rv32i-core:
    @just run-verilog rv32i_core_vlg_tst

test-simple-rom:
    @just run-verilog simple_rom_vlg_tst

test-simple-dual-port-ram:
    @just run-verilog simple_dual_port_ram_vlg_tst

test-onchip-dual-port-ram:
    @just run-verilog onchip_dual_port_ram_vlg_tst

test-simple-bus:
    @just run-verilog simple_bus_vlg_tst

test-gpio-mmio:
    @just run-verilog gpio_mmio_vlg_tst

test-uart-tx:
    @just run-verilog uart_tx_vlg_tst

test-uart-tx-mmio:
    @just run-verilog uart_tx_mmio_vlg_tst

test-spi-master-mmio:
    @just run-verilog spi_master_mmio_vlg_tst

test-sdram-simple-ctrl:
    @just run-verilog sdram_simple_ctrl_vlg_tst

test-sdram-ctrl-wrapper:
    @just run-verilog sdram_ctrl_wrapper_vlg_tst

test-vga-sdram-fb:
    @just run-verilog-with vga_sdram_fb_vlg_tst src/soc/vga/vga_timing.v src/soc/vga/vga_sdram_fb.v src/soc/vga/vga_sdram_fb_vlg_tst.v

test-rv32i-soc: firmware-board-demo
    @just run-verilog rv32i_soc_vlg_tst

test-rv32i-soc-mmio:
    @just run-verilog rv32i_soc_mmio_vlg_tst

test-rv32i-soc-ram-exec:
    @just run-verilog rv32i_soc_ram_exec_vlg_tst

test-rv32i-soc-bootloader-stack: firmware-bootloader
    @just run-verilog rv32i_soc_bootloader_stack_vlg_tst

test-rv32i-soc-init-data: build-app-init-data-test
    @just run-verilog rv32i_soc_init_data_vlg_tst

test-rv32i-soc-soft-float: build-app-soft-float-test
    @just run-verilog rv32i_soc_soft_float_vlg_tst

test-rv32i-soc-sdram-app: build-app-sdram-test-image
    @just run-verilog rv32i_soc_sdram_app_vlg_tst

test-rv32i-soc-vga-app: build-app-vga-test-image
    @just run-verilog rv32i_soc_vga_app_vlg_tst

test-rv32i-soc-snake-app: build-app-snake-image
    @just run-verilog rv32i_soc_snake_app_vlg_tst

test-rv32i-soc-uart-rom: firmware-uart-demo
    @just run-verilog rv32i_soc_uart_rom_vlg_tst

test-rv32i-soc-c-rom: firmware-c-demo
    @just run-verilog rv32i_soc_c_rom_vlg_tst

test-rv32i-soc-selfsale-rom: build-selfsale-test-image
    @just run-verilog-with rv32i_soc_selfsale_rom_vlg_tst {{ selfsale_test_sources }}

test-de1-soc-top: firmware-board-demo
    @just run-verilog de1_soc_top_vlg_tst

clean:
    @rm -rf {{ build_dir }} obj_dir
