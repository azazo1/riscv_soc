`timescale 1ns / 1ps

module rv32i_core_m_ext_vlg_tst;
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

  localparam OPCODE_OP_IMM = 7'b0010011;
  localparam OPCODE_OP = 7'b0110011;
  localparam OPCODE_BRANCH = 7'b1100011;
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
      .dmem_rdata(dmem_rdata)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function [31:0] instr_r;
    input [6:0] funct7;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    begin
      instr_r = {funct7, rs2, rs1, funct3, rd, OPCODE_OP};
    end
  endfunction

  function [31:0] instr_i;
    input [11:0] imm;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    begin
      instr_i = {imm, rs1, funct3, rd, OPCODE_OP_IMM};
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

  always @(*) begin
    case (imem_addr)
      32'h0000_0000: imem_rdata = instr_i(12'd7, 5'd0, 3'b000, 5'd1); // addi x1, x0, 7
      32'h0000_0004: imem_rdata = instr_i(12'd3, 5'd0, 3'b000, 5'd2); // addi x2, x0, 3
      32'h0000_0008: imem_rdata = instr_i(12'hffd, 5'd0, 3'b000, 5'd3); // addi x3, x0, -3
      32'h0000_000c: imem_rdata = instr_r(7'b0000001, 5'd2, 5'd1, 3'b000, 5'd4); // mul x4, x1, x2
      32'h0000_0010: imem_rdata = instr_r(7'b0000001, 5'd2, 5'd3, 3'b100, 5'd5); // div x5, x3, x2
      32'h0000_0014: imem_rdata = instr_r(7'b0000001, 5'd2, 5'd3, 3'b110, 5'd6); // rem x6, x3, x2
      32'h0000_0018: imem_rdata = instr_r(7'b0000001, 5'd0, 5'd1, 3'b101, 5'd7); // divu x7, x1, x0
      32'h0000_001c: imem_rdata = instr_r(7'b0000001, 5'd1, 5'd3, 3'b011, 5'd8); // mulhu x8, x3, x1
      32'h0000_0020: imem_rdata = instr_b(13'd0, 5'd0, 5'd0, 3'b000); // beq x0, x0, 0
      default: imem_rdata = INSTR_NOP;
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
    dmem_rdata = 32'b0;

    #1;
    rst_n = 1'b0;
    #20;
    rst_n = 1'b1;

    repeat (16) @(posedge clk);
    #1;

    expect_value(dut.u_regfile.regs[4], 32'd21, 32'd1);
    expect_value(dut.u_regfile.regs[5], 32'hffff_ffff, 32'd2);
    expect_value(dut.u_regfile.regs[6], 32'd0, 32'd3);
    expect_value(dut.u_regfile.regs[7], 32'hffff_ffff, 32'd4);
    expect_value(dut.u_regfile.regs[8], 32'd6, 32'd5);
    expect_value({31'b0, dmem_req}, 32'b0, 32'd6);
    expect_value({31'b0, dmem_we}, 32'b0, 32'd7);

    $display("rv32i_core_m_ext test passed");
    $finish;
  end
endmodule
