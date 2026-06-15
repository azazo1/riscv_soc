build_dir := "build"
verilog_sources := `find src -type f -name '*.v' -print | sort | tr '\n' ' '`
board_demo_rom_words := "256"
board_demo_rom_fill := "00000013"

default:
    @just --list

build-verilog-with top +sources:
    @mkdir -p {{ build_dir }}/{{ top }}
    @verilator --binary --top-module {{ top }} --Mdir {{ build_dir }}/{{ top }} {{ sources }}

run-verilog-with top +sources:
    @just build-verilog-with {{ top }} {{ sources }}
    @./{{ build_dir }}/{{ top }}/V{{ top }}

build-verilog top:
    @just build-verilog-with {{ top }} {{ verilog_sources }}

run-verilog top:
    @just run-verilog-with {{ top }} {{ verilog_sources }}

firmware: firmware-board-demo

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
    @# xxd -e -g 4 -c 4 把 little-endian 字节按 32-bit 指令 word 输出给 $readmemh.
    @xxd -e -g 4 -c 4 {{ build_dir }}/firmware/board_demo/board_demo.bin | awk '{ print $2 }' > firmware/board_demo/board_demo.hex
    @# MIF 给 Quartus ROM/IP 或 memory update 流程使用, simple_rom 的 $readmemh 仍然读取 hex.
    @awk -v depth={{ board_demo_rom_words }} -v fill={{ board_demo_rom_fill }} 'BEGIN { print "WIDTH=32;"; print "DEPTH=" depth ";"; print ""; print "ADDRESS_RADIX=HEX;"; print "DATA_RADIX=HEX;"; print ""; print "CONTENT BEGIN" } /^[[:space:]]*$/ { next } /^[[:space:]]*\/\// { next } { count++; if (count > depth) { printf "firmware image is larger than ROM depth: %d > %d\n", count, depth > "/dev/stderr"; bad=1; next } printf "  %02X : %s;\n", count - 1, toupper($1) } END { if (bad) exit 1; if (count < depth) printf "  [%02X..%02X] : %s;\n", count, depth - 1, fill; print "END;" }' firmware/board_demo/board_demo.hex > firmware/board_demo/board_demo.mif

test: test-regfile test-alu test-imm-gen test-decoder test-branch-unit test-load-store-unit test-pc-reg test-next-pc-unit test-rv32i-core test-simple-rom test-simple-ram test-simple-bus test-gpio-mmio test-rv32i-soc test-rv32i-soc-mmio test-de1-soc-top

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

test-rv32i-soc: firmware-board-demo
    @just run-verilog rv32i_soc_vlg_tst

test-rv32i-soc-mmio:
    @just run-verilog rv32i_soc_mmio_vlg_tst

test-de1-soc-top: firmware-board-demo
    @just run-verilog de1_soc_top_vlg_tst

clean:
    @rm -rf {{ build_dir }} obj_dir
