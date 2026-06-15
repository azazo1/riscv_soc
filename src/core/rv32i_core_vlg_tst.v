`timescale 1ns / 1ps

module rv32i_core_vlg_tst;
  reg clk;
  reg rst_n;

  wire [31:0] imem_addr;
  reg  [31:0] imem_rdata;

  wire        dmem_req;
  wire        dmem_we;
  wire [ 3:0] dmem_be;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  reg  [31:0] dmem_rdata;

  reg [31:0] data_mem[0:15];
  integer i;

  localparam OPCODE_LUI = 7'b0110111;
  localparam OPCODE_AUIPC = 7'b0010111;
  localparam OPCODE_JAL = 7'b1101111;
  localparam OPCODE_JALR = 7'b1100111;
  localparam OPCODE_BRANCH = 7'b1100011;
  localparam OPCODE_LOAD = 7'b0000011;
  localparam OPCODE_STORE = 7'b0100011;
  localparam OPCODE_OP_IMM = 7'b0010011;
  localparam OPCODE_OP = 7'b0110011;

  localparam INSTR_NOP = 32'h0000_0013;

  rv32i_core dut (
      .clk(clk),
      .rst_n(rst_n),
      .imem_addr(imem_addr),
      .imem_rdata(imem_rdata),
      .dmem_req(dmem_req),
      .dmem_we(dmem_we),
      .dmem_be(dmem_be),
      .dmem_addr(dmem_addr),
      .dmem_wdata(dmem_wdata),
      .dmem_rdata(dmem_rdata),
      .dmem_ready(1'b1)
  );

  // 100MHz clock
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // R-type 指令编码.
  function [31:0] instr_r;
    input [6:0] funct7;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    input [6:0] opcode;
    begin
      instr_r = {funct7, rs2, rs1, funct3, rd, opcode};
    end
  endfunction

  // I-type 指令编码, 用于 OP-IMM, LOAD, JALR.
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

  // S-type 指令编码, 用于 STORE.
  function [31:0] instr_s;
    input [11:0] imm;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    begin
      instr_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], OPCODE_STORE};
    end
  endfunction

  // B-type 指令编码, 分支立即数最低位固定为 0.
  function [31:0] instr_b;
    input [12:0] imm;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    begin
      instr_b = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], OPCODE_BRANCH};
    end
  endfunction

  // U-type 指令编码, 用于 LUI 和 AUIPC.
  function [31:0] instr_u;
    input [19:0] imm20;
    input [4:0] rd;
    input [6:0] opcode;
    begin
      instr_u = {imm20, rd, opcode};
    end
  endfunction

  // J-type 指令编码, JAL 立即数最低位固定为 0.
  function [31:0] instr_j;
    input [20:0] imm;
    input [4:0] rd;
    begin
      instr_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, OPCODE_JAL};
    end
  endfunction

  always @(*) begin
    case (imem_addr)
      32'h0000_0000: imem_rdata = instr_i(12'd5, 5'd0, 3'b000, 5'd1, OPCODE_OP_IMM); // addi x1, x0, 5
      32'h0000_0004: imem_rdata = instr_i(12'd7, 5'd0, 3'b000, 5'd2, OPCODE_OP_IMM); // addi x2, x0, 7
      32'h0000_0008: imem_rdata = instr_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, OPCODE_OP); // add x3, x1, x2
      32'h0000_000c: imem_rdata = instr_r(7'b0100000, 5'd1, 5'd3, 3'b000, 5'd4, OPCODE_OP); // sub x4, x3, x1
      32'h0000_0010: imem_rdata = instr_u(20'h12345, 5'd5, OPCODE_LUI); // lui x5, 0x12345
      32'h0000_0014: imem_rdata = instr_u(20'h00001, 5'd6, OPCODE_AUIPC); // auipc x6, 0x1
      32'h0000_0018: imem_rdata = instr_s(12'd0, 5'd3, 5'd0, 3'b010); // sw x3, 0(x0)
      32'h0000_001c: imem_rdata = instr_i(12'd0, 5'd0, 3'b010, 5'd7, OPCODE_LOAD); // lw x7, 0(x0)
      32'h0000_0020: imem_rdata = instr_b(13'd8, 5'd3, 5'd7, 3'b000); // beq x7, x3, +8
      32'h0000_0024: imem_rdata = instr_i(12'd1, 5'd0, 3'b000, 5'd8, OPCODE_OP_IMM); // skipped
      32'h0000_0028: imem_rdata = instr_j(21'd8, 5'd9); // jal x9, +8
      32'h0000_002c: imem_rdata = instr_i(12'd1, 5'd0, 3'b000, 5'd10, OPCODE_OP_IMM); // skipped
      32'h0000_0030: imem_rdata = instr_i(12'd42, 5'd0, 3'b000, 5'd11, OPCODE_OP_IMM); // addi x11, x0, 42
      32'h0000_0034: imem_rdata = instr_i(12'd64, 5'd0, 3'b000, 5'd12, OPCODE_OP_IMM); // addi x12, x0, 64
      32'h0000_0038: imem_rdata = instr_i(12'd0, 5'd12, 3'b000, 5'd13, OPCODE_JALR); // jalr x13, 0(x12)
      32'h0000_003c: imem_rdata = instr_i(12'd1, 5'd0, 3'b000, 5'd14, OPCODE_OP_IMM); // skipped
      32'h0000_0040: imem_rdata = instr_i(12'd99, 5'd0, 3'b000, 5'd15, OPCODE_OP_IMM); // addi x15, x0, 99
      32'h0000_0044: imem_rdata = instr_b(13'd0, 5'd0, 5'd0, 3'b000); // beq x0, x0, 0
      default: imem_rdata = INSTR_NOP;
    endcase
  end

  always @(*) begin
    if (dmem_addr[31:6] == 26'd0) begin
      dmem_rdata = data_mem[dmem_addr[5:2]];
    end else begin
      dmem_rdata = 32'b0;
    end
  end

  always @(posedge clk) begin
    if (rst_n && dmem_req && dmem_we) begin
      if (dmem_be != 4'b1111) begin
        $display("unexpected store byte enable: got %b", dmem_be);
        $fatal;
      end
      data_mem[dmem_addr[5:2]] <= dmem_wdata;
    end
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
    for (i = 0; i < 16; i = i + 1) begin
      data_mem[i] = 32'b0;
    end

    #1;
    rst_n = 1'b0;
    #20;
    rst_n = 1'b1;

    repeat (24) @(posedge clk);
    #1;

    expect_value(dut.u_regfile.regs[1], 32'd5, 32'd1);
    expect_value(dut.u_regfile.regs[2], 32'd7, 32'd2);
    expect_value(dut.u_regfile.regs[3], 32'd12, 32'd3);
    expect_value(dut.u_regfile.regs[4], 32'd7, 32'd4);
    expect_value(dut.u_regfile.regs[5], 32'h1234_5000, 32'd5);
    expect_value(dut.u_regfile.regs[6], 32'h0000_1014, 32'd6);
    expect_value(data_mem[0], 32'd12, 32'd7);
    expect_value(dut.u_regfile.regs[7], 32'd12, 32'd8);
    expect_value(dut.u_regfile.regs[8], 32'd0, 32'd9);
    expect_value(dut.u_regfile.regs[9], 32'h0000_002c, 32'd10);
    expect_value(dut.u_regfile.regs[10], 32'd0, 32'd11);
    expect_value(dut.u_regfile.regs[11], 32'd42, 32'd12);
    expect_value(dut.u_regfile.regs[12], 32'd64, 32'd13);
    expect_value(dut.u_regfile.regs[13], 32'h0000_003c, 32'd14);
    expect_value(dut.u_regfile.regs[14], 32'd0, 32'd15);
    expect_value(dut.u_regfile.regs[15], 32'd99, 32'd16);
    expect_value(imem_addr, 32'h0000_0044, 32'd17);

    $display("rv32i_core test passed");
    $finish;
  end
endmodule
