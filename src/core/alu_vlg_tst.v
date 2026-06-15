`timescale 1ns / 1ps

module alu_vlg_tst;

  reg  [ 4:0] alu_op;
  reg  [31:0] lhs;
  reg  [31:0] rhs;
  wire [31:0] result;

  localparam ALU_ADD = 5'd0;
  localparam ALU_SUB = 5'd1;
  localparam ALU_SLL = 5'd2;
  localparam ALU_SLT = 5'd3;
  localparam ALU_SLTU = 5'd4;
  localparam ALU_XOR = 5'd5;
  localparam ALU_SRL = 5'd6;
  localparam ALU_SRA = 5'd7;
  localparam ALU_OR = 5'd8;
  localparam ALU_AND = 5'd9;
  localparam ALU_MUL = 5'd10;
  localparam ALU_MULH = 5'd11;
  localparam ALU_MULHSU = 5'd12;
  localparam ALU_MULHU = 5'd13;
  localparam ALU_DIV = 5'd14;
  localparam ALU_DIVU = 5'd15;
  localparam ALU_REM = 5'd16;
  localparam ALU_REMU = 5'd17;

  task expect_result;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      #1;
      if (result != expected) begin
        $display("check %0d failed: expected %h, got %h", check_id, expected, result);
        $fatal;
      end
    end
  endtask

  alu dut (
      .alu_op(alu_op),
      .lhs(lhs),
      .rhs(rhs),
      .result(result)
  );

  initial begin
    // ADD
    alu_op = ALU_ADD;
    lhs = 32'd10;
    rhs = 32'd20;
    #1;
    if (result != 32'd30) begin
      $display("ADD failed: expected 30, got %d", result);
      $fatal;
    end

    // SUB
    alu_op = ALU_SUB;
    lhs = 32'd219;
    rhs = 32'd10293;
    #1;
    if (result != -32'd10074) begin
      $display("SUB failed: expected -10074, got %d", result);
      $fatal;
    end

    // SLL
    alu_op = ALU_SLL;
    lhs = 32'h0000_0001;
    rhs = 32'd16;
    #1;
    if (result != 32'h00010000) begin
      $display("SLL failed: expected 0x00010000, got %h", result);
      $fatal;
    end

    // SLT
    alu_op = ALU_SLT;
    lhs = -32'h10;
    rhs = 32'h10;
    #1;
    if (result != 32'd1) begin
      $display("SLT failed: expected 1, got %d", result);
      $fatal;
    end

    // SLTU
    alu_op = ALU_SLTU;
    lhs = -32'h10;
    rhs = 32'h10;
    #1;
    if (result != 32'd0) begin
      $display("SLTU failed: expected 0, got %d", result);
      $fatal;
    end

    // XOR
    alu_op = ALU_XOR;
    lhs = 32'hA5A5A5A5;
    rhs = 32'h5A5A5A5A;
    #1;
    if (result != 32'hFFFFFFFF) begin
      $display("XOR failed: expected 0xFFFFFFFF, got %h", result);
      $fatal;
    end

    // SRL
    alu_op = ALU_SRL;
    lhs = 32'h1000_0000;
    rhs = 32'd16;
    #1;
    if (result != 32'h00001000) begin
      $display("SRL failed: expected 0x00001000, got %h", result);
      $fatal;
    end

    // SRA
    alu_op = ALU_SRA;
    lhs = 32'h8000_0000;
    rhs = 32'd16;
    #1;
    if (result != 32'hFFFF8000) begin
      $display("SRA failed: expected 0xFFFF8000, got %h", result);
      $fatal;
    end

    // OR
    alu_op = ALU_OR;
    lhs = 32'hA5A50000;
    rhs = 32'h5A5A0000;
    #1;
    if (result != 32'hFFFF0000) begin
      $display("OR failed: expected 0xFFFF0000, got %h", result);
      $fatal;
    end

    // AND
    alu_op = ALU_AND;
    lhs = 32'hA5A5FF00;
    rhs = 32'h5A5AFF00;
    #1;
	    if (result != 32'h0000FF00) begin
	      $display("AND failed: expected 0x0000FF00, got %h", result);
	      $fatal;
	    end

    // RV32M: MUL 只取低 32 bit.
    alu_op = ALU_MUL;
    lhs = 32'hffff_fffe;
    rhs = 32'd3;
    expect_result(32'hffff_fffa, 32'd101);

    // RV32M: MULH 取 signed * signed 的高 32 bit.
    alu_op = ALU_MULH;
    lhs = 32'hffff_fffe;
    rhs = 32'd3;
    expect_result(32'hffff_ffff, 32'd102);

    // RV32M: MULHSU 取 signed * unsigned 的高 32 bit.
    alu_op = ALU_MULHSU;
    lhs = 32'hffff_fffe;
    rhs = 32'hffff_ffff;
    expect_result(32'hffff_fffe, 32'd103);

    // RV32M: MULHU 取 unsigned * unsigned 的高 32 bit.
    alu_op = ALU_MULHU;
    lhs = 32'hffff_ffff;
    rhs = 32'hffff_ffff;
    expect_result(32'hffff_fffe, 32'd104);

    // RV32M: 有符号除法向 0 取整.
    alu_op = ALU_DIV;
    lhs = -32'd7;
    rhs = 32'd3;
    expect_result(32'hffff_fffe, 32'd105);

    // RV32M: 无符号除法.
    alu_op = ALU_DIVU;
    lhs = 32'd7;
    rhs = 32'd3;
    expect_result(32'd2, 32'd106);

    // RV32M: 有符号取余保留被除数符号.
    alu_op = ALU_REM;
    lhs = -32'd7;
    rhs = 32'd3;
    expect_result(32'hffff_ffff, 32'd107);

    // RV32M: 无符号取余.
    alu_op = ALU_REMU;
    lhs = 32'd7;
    rhs = 32'd3;
    expect_result(32'd1, 32'd108);

    // RV32M: 除以 0 的商固定为全 1, 余数返回被除数.
    alu_op = ALU_DIV;
    lhs = 32'd7;
    rhs = 32'd0;
    expect_result(32'hffff_ffff, 32'd109);

    alu_op = ALU_REM;
    lhs = 32'd7;
    rhs = 32'd0;
    expect_result(32'd7, 32'd110);

    // RV32M: INT_MIN / -1 溢出时商为 INT_MIN, 余数为 0.
    alu_op = ALU_DIV;
    lhs = 32'h8000_0000;
    rhs = 32'hffff_ffff;
    expect_result(32'h8000_0000, 32'd111);

    alu_op = ALU_REM;
    lhs = 32'h8000_0000;
    rhs = 32'hffff_ffff;
    expect_result(32'd0, 32'd112);

	    $display("alu test passed");
    $finish;
  end
endmodule
