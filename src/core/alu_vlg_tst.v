`timescale 1ns / 1ps

module alu_vlg_tst;

  reg  [ 3:0] alu_op;
  reg  [31:0] lhs;
  reg  [31:0] rhs;
  wire [31:0] result;

  localparam ALU_ADD = 4'd0;
  localparam ALU_SUB = 4'd1;
  localparam ALU_SLL = 4'd2;
  localparam ALU_SLT = 4'd3;
  localparam ALU_SLTU = 4'd4;
  localparam ALU_XOR = 4'd5;
  localparam ALU_SRL = 4'd6;
  localparam ALU_SRA = 4'd7;
  localparam ALU_OR = 4'd8;
  localparam ALU_AND = 4'd9;

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
  end
endmodule
