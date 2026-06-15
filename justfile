build_dir := "build"
verilog_sources := `find src -type f -name '*.v' -print | sort | tr '\n' ' '`

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

firmware: firmware-board-demo firmware-uart-demo firmware-bootloader

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
    @# linker.ld 固定 ROM=0x0000_0000, RAM=0x0000_8000, 并提供 _stack_top 等启动符号.
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

build-app-board:
    @mkdir -p {{ build_dir }}/firmware/sdcard
    @# init.bin 是 SD bootloader 读取的原始 binary, 入口地址按 0x0000_8000 链接.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -I firmware/include -c -o {{ build_dir }}/firmware/sdcard/main.o firmware/init_app/board_app.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/firmware/sdcard/startup.o firmware/c_demo/startup.S
    @# 用 zig cc 链接, 让 compiler-rt 提供 __mulsi3, __divsi3 等软件整数 helper.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,firmware/init_app/linker.ld -Wl,--gc-sections -o {{ build_dir }}/firmware/sdcard/init.elf {{ build_dir }}/firmware/sdcard/startup.o {{ build_dir }}/firmware/sdcard/main.o
    @# init_app 整体在 RAM 中运行, 所以 .data 初值可以直接放进 init.bin.
    riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data {{ build_dir }}/firmware/sdcard/init.elf {{ build_dir }}/firmware/sdcard/init.bin
    @riscv64-elf-size {{ build_dir }}/firmware/sdcard/init.elf

build-app-init-data-test:
    @mkdir -p {{ build_dir }}/tests/init_data_test
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -I firmware/include -c -o {{ build_dir }}/tests/init_data_test/main.o firmware/init_app/init_data_test.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/tests/init_data_test/startup.o firmware/c_demo/startup.S
    @# 用 zig cc 链接, 让 compiler-rt 提供 __mulsi3, __divsi3 等软件整数 helper.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -Wl,-T,firmware/init_app/linker.ld -Wl,--gc-sections -o {{ build_dir }}/tests/init_data_test/init_data_test.elf {{ build_dir }}/tests/init_data_test/startup.o {{ build_dir }}/tests/init_data_test/main.o
    riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data {{ build_dir }}/tests/init_data_test/init_data_test.elf {{ build_dir }}/tests/init_data_test/init_data_test.bin
    @just bin-to-rom-hex {{ build_dir }}/tests/init_data_test/init_data_test.bin {{ build_dir }}/tests/init_data_test/init_data_test.hex
    @riscv64-elf-size {{ build_dir }}/tests/init_data_test/init_data_test.elf

build-app-soft-float-test:
    @mkdir -p {{ build_dir }}/tests/soft_float_test
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -ffunction-sections -fdata-sections -I firmware/include -c -o {{ build_dir }}/tests/soft_float_test/main.o firmware/init_app/soft_float_test.c
    riscv64-elf-as -march=rv32i -mabi=ilp32 -o {{ build_dir }}/tests/soft_float_test/startup.o firmware/c_demo/startup.S
    @# 用 zig cc 链接, 让 Zig 自动带上 compiler-rt builtins, 例如 __addsf3, __mulsf3.
    @# --gc-sections 会丢弃没有用到的 helper, 否则软浮点运行时会明显变大.
    zig cc -target riscv32-freestanding -mcpu=baseline_rv32-m-a-f-d-c-zicsr-zmmul-zaamo-zalrsc-zca-zcd-zcf -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-unwind-tables -ffunction-sections -fdata-sections -Wl,--gc-sections -Wl,-T,firmware/init_app/linker.ld -o {{ build_dir }}/tests/soft_float_test/soft_float_test.elf {{ build_dir }}/tests/soft_float_test/startup.o {{ build_dir }}/tests/soft_float_test/main.o
    riscv64-elf-objcopy -O binary -j .text -j .rodata -j .data {{ build_dir }}/tests/soft_float_test/soft_float_test.elf {{ build_dir }}/tests/soft_float_test/soft_float_test.bin
    @just bin-to-rom-hex {{ build_dir }}/tests/soft_float_test/soft_float_test.bin {{ build_dir }}/tests/soft_float_test/soft_float_test.hex
    @riscv64-elf-size {{ build_dir }}/tests/soft_float_test/soft_float_test.elf

bin-to-rom-hex input output:
    @# xxd -e -g 4 -c 4 把 little-endian 字节按 32-bit word 输出给 $readmemh.
    @xxd -e -g 4 -c 4 {{ input }} | awk '{ print $2 }' > {{ output }}

test: test-regfile test-alu test-imm-gen test-decoder test-branch-unit test-load-store-unit test-pc-reg test-next-pc-unit test-rv32i-core test-simple-rom test-simple-ram test-simple-bus test-gpio-mmio test-uart-tx test-uart-tx-mmio test-spi-master-mmio test-rv32i-soc test-rv32i-soc-mmio test-rv32i-soc-ram-exec test-rv32i-soc-init-data test-rv32i-soc-soft-float test-rv32i-soc-uart-rom test-rv32i-soc-c-rom test-de1-soc-top

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

test-simple-ram:
    @just run-verilog simple_ram_vlg_tst

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

test-rv32i-soc: firmware-board-demo
    @just run-verilog rv32i_soc_vlg_tst

test-rv32i-soc-mmio:
    @just run-verilog rv32i_soc_mmio_vlg_tst

test-rv32i-soc-ram-exec:
    @just run-verilog rv32i_soc_ram_exec_vlg_tst

test-rv32i-soc-init-data: build-app-init-data-test
    @just run-verilog rv32i_soc_init_data_vlg_tst

test-rv32i-soc-soft-float: build-app-soft-float-test
    @just run-verilog rv32i_soc_soft_float_vlg_tst

test-rv32i-soc-uart-rom: firmware-uart-demo
    @just run-verilog rv32i_soc_uart_rom_vlg_tst

test-rv32i-soc-c-rom: firmware-c-demo
    @just run-verilog rv32i_soc_c_rom_vlg_tst

test-de1-soc-top: firmware-board-demo
    @just run-verilog de1_soc_top_vlg_tst

clean:
    @rm -rf {{ build_dir }} obj_dir
