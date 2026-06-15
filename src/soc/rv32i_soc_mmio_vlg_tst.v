`timescale 1ns / 1ps

module rv32i_soc_mmio_vlg_tst;
  reg clk;
  reg rst_n;

  wire [31:0] imem_addr;
  reg [31:0] imem_rdata;

  wire dmem_req;
  wire dmem_we;
  wire [3:0] dmem_be;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  wire [31:0] dmem_rdata;

  wire ram_req;
  wire ram_we;
  wire [3:0] ram_be;
  wire [31:0] ram_addr;
  wire [31:0] ram_wdata;
  wire [31:0] ram_rdata;

  wire gpio_req;
  wire gpio_we;
  wire [3:0] gpio_be;
  wire [31:0] gpio_addr;
  wire [31:0] gpio_wdata;
  wire [31:0] gpio_rdata;

  reg [9:0] sw;
  reg [3:0] key;
  wire [9:0] ledr;
  wire [6:0] hex0;
  wire [6:0] hex1;
  wire [6:0] hex2;
  wire [6:0] hex3;
  wire [6:0] hex4;
  wire [6:0] hex5;
  reg [35:0] gpio0_in;
  reg [35:0] gpio1_in;
  wire [35:0] gpio0_out;
  wire [35:0] gpio0_oe;
  wire [35:0] gpio1_out;
  wire [35:0] gpio1_oe;

  localparam OPCODE_LUI = 7'b0110111;
  localparam OPCODE_OP_IMM = 7'b0010011;
  localparam OPCODE_LOAD = 7'b0000011;
  localparam OPCODE_STORE = 7'b0100011;
  localparam OPCODE_BRANCH = 7'b1100011;

  rv32i_core u_core (
      .clk(clk),
      .rst_n(rst_n),
      .imem_addr(imem_addr),
      .imem_rdata(imem_rdata),
      .dmem_req(dmem_req),
      .dmem_we(dmem_we),
      .dmem_be(dmem_be),
      .dmem_addr(dmem_addr),
      .dmem_wdata(dmem_wdata),
      .dmem_rdata(dmem_rdata)
  );

  simple_bus u_bus (
      .clk(clk),
      .req(dmem_req),
      .we(dmem_we),
      .be(dmem_be),
      .addr(dmem_addr),
      .wdata(dmem_wdata),
      .rdata(dmem_rdata),
      .ram_req(ram_req),
      .ram_we(ram_we),
      .ram_be(ram_be),
      .ram_addr(ram_addr),
      .ram_wdata(ram_wdata),
      .ram_rdata(ram_rdata),
      .gpio_req(gpio_req),
      .gpio_we(gpio_we),
      .gpio_be(gpio_be),
      .gpio_addr(gpio_addr),
      .gpio_wdata(gpio_wdata),
      .gpio_rdata(gpio_rdata)
  );

  simple_ram u_ram (
      .clk(clk),
      .rst_n(rst_n),
      .req(ram_req),
      .we(ram_we),
      .be(ram_be),
      .addr(ram_addr),
      .wdata(ram_wdata),
      .rdata(ram_rdata)
  );

  gpio_mmio u_gpio (
      .clk(clk),
      .rst_n(rst_n),
      .req(gpio_req),
      .we(gpio_we),
      .be(gpio_be),
      .addr(gpio_addr),
      .wdata(gpio_wdata),
      .sw(sw),
      .key(key),
      .gpio0_in(gpio0_in),
      .gpio1_in(gpio1_in),
      .rdata(gpio_rdata),
      .ledr(ledr),
      .hex0(hex0),
      .hex1(hex1),
      .hex2(hex2),
      .hex3(hex3),
      .hex4(hex4),
      .hex5(hex5),
      .gpio0_out(gpio0_out),
      .gpio0_oe(gpio0_oe),
      .gpio1_out(gpio1_out),
      .gpio1_oe(gpio1_oe)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function [31:0] instr_i;
    input [11:0] imm;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    input [6:0] opcode;
    begin
      instr_i = {imm, rs1, funct3, rd, opcode};
    end
  endfunction

  function [31:0] instr_s;
    input [11:0] imm;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    begin
      instr_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], OPCODE_STORE};
    end
  endfunction

  function [31:0] instr_b;
    input [12:0] imm;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    begin
      instr_b = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], OPCODE_BRANCH};
    end
  endfunction

  function [31:0] instr_u;
    input [19:0] imm20;
    input [4:0] rd;
    input [6:0] opcode;
    begin
      instr_u = {imm20, rd, opcode};
    end
  endfunction

  always @(*) begin
    case (imem_addr)
      32'h0000_0000: imem_rdata = instr_u(20'h01000, 5'd1, OPCODE_LUI); // lui x1, 0x01000, x1 = 0x0100_0000, MMIO 基地址
      32'h0000_0004: imem_rdata = instr_i(12'h155, 5'd0, 3'b000, 5'd2, OPCODE_OP_IMM); // addi x2, x0, 0x155, 准备写入 LEDR
      32'h0000_0008: imem_rdata = instr_s(12'd0, 5'd2, 5'd1, 3'b010); // sw x2, 0(x1), 写 LEDR 寄存器
      32'h0000_000c: imem_rdata = instr_i(12'd4, 5'd1, 3'b010, 5'd3, OPCODE_LOAD); // lw x3, 4(x1), 读取 SW 寄存器
      32'h0000_0010: imem_rdata = instr_i(12'd8, 5'd1, 3'b010, 5'd4, OPCODE_LOAD); // lw x4, 8(x1), 读取 KEY 寄存器
      32'h0000_0014: imem_rdata = instr_u(20'h3f066, 5'd5, OPCODE_LUI); // lui x5, 0x3f066, 准备 HEX_LOW 段码高位
      32'h0000_0018: imem_rdata = instr_i(12'hb4f, 5'd5, 3'b000, 5'd5, OPCODE_OP_IMM); // addi x5, x5, 0xb4f, x5 = 0x3f06_5b4f
      32'h0000_001c: imem_rdata = instr_s(12'd12, 5'd5, 5'd1, 3'b010); // sw x5, 12(x1), 写 HEX0 到 HEX3
      32'h0000_0020: imem_rdata = instr_u(20'h00001, 5'd6, OPCODE_LUI); // lui x6, 0x00001, 准备 HEX_HIGH 段码高位
      32'h0000_0024: imem_rdata = instr_i(12'h219, 5'd6, 3'b000, 5'd6, OPCODE_OP_IMM); // addi x6, x6, 0x219, x6 = 0x0000_1219
      32'h0000_0028: imem_rdata = instr_s(12'd16, 5'd6, 5'd1, 3'b010); // sw x6, 16(x1), 写 HEX4 到 HEX5
      32'h0000_002c: imem_rdata = instr_i(12'd32, 5'd1, 3'b010, 5'd7, OPCODE_LOAD); // lw x7, 32(x1), 读取 GPIO0_IN_LOW
      32'h0000_0030: imem_rdata = instr_i(12'd36, 5'd1, 3'b010, 5'd8, OPCODE_LOAD); // lw x8, 36(x1), 读取 GPIO0_IN_HIGH
      32'h0000_0034: imem_rdata = instr_i(12'h5a5, 5'd0, 3'b000, 5'd9, OPCODE_OP_IMM); // addi x9, x0, 0x5a5, 准备 GPIO0 输出值
      32'h0000_0038: imem_rdata = instr_s(12'd40, 5'd9, 5'd1, 3'b010); // sw x9, 40(x1), 写 GPIO0_OUT_LOW
      32'h0000_003c: imem_rdata = instr_i(12'd10, 5'd0, 3'b000, 5'd10, OPCODE_OP_IMM); // addi x10, x0, 10, 准备 GPIO0 高 4 bit 输出值
      32'h0000_0040: imem_rdata = instr_s(12'd44, 5'd10, 5'd1, 3'b010); // sw x10, 44(x1), 写 GPIO0_OUT_HIGH
      32'h0000_0044: imem_rdata = instr_i(12'hfff, 5'd0, 3'b000, 5'd11, OPCODE_OP_IMM); // addi x11, x0, -1, 准备 GPIO0_OE_LOW
      32'h0000_0048: imem_rdata = instr_s(12'd48, 5'd11, 5'd1, 3'b010); // sw x11, 48(x1), 写 GPIO0_OE_LOW
      32'h0000_004c: imem_rdata = instr_i(12'd3, 5'd0, 3'b000, 5'd12, OPCODE_OP_IMM); // addi x12, x0, 3, 准备 GPIO0_OE_HIGH
      32'h0000_0050: imem_rdata = instr_s(12'd52, 5'd12, 5'd1, 3'b010); // sw x12, 52(x1), 写 GPIO0_OE_HIGH
      32'h0000_0054: imem_rdata = instr_i(12'd64, 5'd1, 3'b010, 5'd13, OPCODE_LOAD); // lw x13, 64(x1), 读取 GPIO1_IN_LOW
      32'h0000_0058: imem_rdata = instr_i(12'd68, 5'd1, 3'b010, 5'd14, OPCODE_LOAD); // lw x14, 68(x1), 读取 GPIO1_IN_HIGH
      32'h0000_005c: imem_rdata = instr_i(12'h333, 5'd0, 3'b000, 5'd15, OPCODE_OP_IMM); // addi x15, x0, 0x333, 准备 GPIO1 输出值
      32'h0000_0060: imem_rdata = instr_s(12'd72, 5'd15, 5'd1, 3'b010); // sw x15, 72(x1), 写 GPIO1_OUT_LOW
      32'h0000_0064: imem_rdata = instr_i(12'd5, 5'd0, 3'b000, 5'd16, OPCODE_OP_IMM); // addi x16, x0, 5, 准备 GPIO1 高 4 bit 输出值
      32'h0000_0068: imem_rdata = instr_s(12'd76, 5'd16, 5'd1, 3'b010); // sw x16, 76(x1), 写 GPIO1_OUT_HIGH
      32'h0000_006c: imem_rdata = instr_i(12'h0f0, 5'd0, 3'b000, 5'd17, OPCODE_OP_IMM); // addi x17, x0, 0x0f0, 准备 GPIO1_OE_LOW
      32'h0000_0070: imem_rdata = instr_s(12'd80, 5'd17, 5'd1, 3'b010); // sw x17, 80(x1), 写 GPIO1_OE_LOW
      32'h0000_0074: imem_rdata = instr_i(12'd6, 5'd0, 3'b000, 5'd18, OPCODE_OP_IMM); // addi x18, x0, 6, 准备 GPIO1_OE_HIGH
      32'h0000_0078: imem_rdata = instr_s(12'd84, 5'd18, 5'd1, 3'b010); // sw x18, 84(x1), 写 GPIO1_OE_HIGH
      32'h0000_007c: imem_rdata = instr_b(13'd0, 5'd0, 5'd0, 3'b000); // beq x0, x0, 0, 原地循环停住
      default: imem_rdata = 32'h0000_0013;
    endcase
  end

  task expect_value;
    input [31:0] actual;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      if (actual !== expected) begin
        $display("check %0d failed: expected %h, got %h", check_id, expected, actual);
        $fatal;
      end
    end
  endtask

  initial begin
    rst_n = 1'b1;
    sw = 10'h2a5;
    key = 4'ha;
    gpio0_in = 36'hf_1234_5678;
    gpio1_in = 36'h5_dead_beef;

    #1;
    rst_n = 1'b0;
    #20;
    rst_n = 1'b1;

    repeat (60) @(posedge clk);
    #1;

    expect_value({22'b0, ledr}, 32'h0000_0155, 32'd1);
    expect_value(u_core.u_regfile.regs[3], 32'h0000_02a5, 32'd2);
    expect_value(u_core.u_regfile.regs[4], 32'h0000_000a, 32'd3);
    expect_value({1'b0, hex3, 1'b0, hex2, 1'b0, hex1, 1'b0, hex0}, 32'h3f06_5b4f, 32'd4);
    expect_value({16'b0, 1'b0, hex5, 1'b0, hex4}, 32'h0000_1219, 32'd5);
    expect_value(u_ram.ram_data[0], 32'h0000_0000, 32'd6);
    expect_value(u_core.u_regfile.regs[7], 32'h1234_5678, 32'd7);
    expect_value(u_core.u_regfile.regs[8], 32'h0000_000f, 32'd8);
    expect_value(gpio0_out[31:0], 32'h0000_05a5, 32'd9);
    expect_value({28'b0, gpio0_out[35:32]}, 32'h0000_000a, 32'd10);
    expect_value(gpio0_oe[31:0], 32'hffff_ffff, 32'd11);
    expect_value({28'b0, gpio0_oe[35:32]}, 32'h0000_0003, 32'd12);
    expect_value(u_core.u_regfile.regs[13], 32'hdead_beef, 32'd13);
    expect_value(u_core.u_regfile.regs[14], 32'h0000_0005, 32'd14);
    expect_value(gpio1_out[31:0], 32'h0000_0333, 32'd15);
    expect_value({28'b0, gpio1_out[35:32]}, 32'h0000_0005, 32'd16);
    expect_value(gpio1_oe[31:0], 32'h0000_00f0, 32'd17);
    expect_value({28'b0, gpio1_oe[35:32]}, 32'h0000_0006, 32'd18);

    $display("rv32i_soc_mmio test passed");
    $finish;
  end
endmodule
