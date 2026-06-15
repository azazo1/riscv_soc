build_dir := "build"
verilog_sources := `find src -type f -name '*.v' -print | sort | tr '\n' ' '`

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

test: test-regfile test-alu test-imm-gen test-decoder test-branch-unit test-load-store-unit test-pc-reg test-next-pc-unit test-rv32i-core test-simple-rom test-simple-ram

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

clean:
    @rm -rf {{ build_dir }} obj_dir
