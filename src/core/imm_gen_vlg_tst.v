`timescale 1ns / 1ps

module imm_gen_vlg_tst;
  reg  [31:0] instr;
  reg  [31:0] branch_imm;
  reg  [31:0] jump_imm;

  wire [31:0] imm_i;
  wire [31:0] imm_s;
  wire [31:0] imm_b;
  wire [31:0] imm_u;
  wire [31:0] imm_j;

  imm_gen dut (
      .instr(instr),
      .imm_i(imm_i),
      .imm_s(imm_s),
      .imm_b(imm_b),
      .imm_u(imm_u),
      .imm_j(imm_j)
  );

  initial begin
    // I-type positive immediate: addi x1, x2, 0x123
    instr = {12'h123, 5'd2, 3'b000, 5'd1, 7'b0010011};
    #1;
    if (imm_i != 32'h0000_0123) begin
      $display("I-type positive failed: expected 0x00000123, got %h", imm_i);
      $fatal;
    end

    // I-type negative immediate: addi x1, x2, -1
    instr = {12'hfff, 5'd2, 3'b000, 5'd1, 7'b0010011};
    #1;
    if (imm_i != 32'hffff_ffff) begin
      $display("I-type negative failed: expected 0xffffffff, got %h", imm_i);
      $fatal;
    end

    // S-type negative immediate: sw x3, -16(x4)
    instr = {7'b1111111, 5'd3, 5'd4, 3'b010, 5'b10000, 7'b0100011};
    #1;
    if (imm_s != 32'hffff_fff0) begin
      $display("S-type negative failed: expected 0xfffffff0, got %h", imm_s);
      $fatal;
    end

    // S-type positive immediate: sw x3, 20(x4)
    instr = {7'b0000000, 5'd3, 5'd4, 3'b010, 5'b10100, 7'b0100011};
    #1;
    if (imm_s != 32'h0000_0014) begin
      $display("S-type positive failed: expected 0x00000014, got %h", imm_s);
      $fatal;
    end

    // U-type immediate: lui x1, 0xabcde
    instr = {20'habcde, 5'd1, 7'b0110111};
    #1;
    if (imm_u != 32'habcde000) begin
      $display("U-type failed: expected 0xabcde000, got %h", imm_u);
      $fatal;
    end

    // B-type positive immediate: beq x1, x2, 16
    branch_imm = 32'd16;
    instr = {
      branch_imm[12],
      branch_imm[10:5],
      5'd2,
      5'd1,
      3'b000,
      branch_imm[4:1],
      branch_imm[11],
      7'b1100011
    };
    #1;
    if (imm_b != 32'h0000_0010) begin
      $display("B-type positive failed: expected 0x00000010, got %h", imm_b);
      $fatal;
    end

    // B-type negative immediate: beq x1, x2, -4
    branch_imm = -32'sd4;
    instr = {
      branch_imm[12],
      branch_imm[10:5],
      5'd2,
      5'd1,
      3'b000,
      branch_imm[4:1],
      branch_imm[11],
      7'b1100011
    };
    #1;
    if (imm_b != 32'hffff_fffc) begin
      $display("B-type negative failed: expected 0xfffffffc, got %h", imm_b);
      $fatal;
    end

    // J-type positive immediate: jal x1, 2048
    jump_imm = 32'd2048;
    instr = {
      jump_imm[20],
      jump_imm[10:1],
      jump_imm[11],
      jump_imm[19:12],
      5'd1,
      7'b1101111
    };
    #1;
    if (imm_j != 32'h0000_0800) begin
      $display("J-type positive failed: expected 0x00000800, got %h", imm_j);
      $fatal;
    end

    // J-type negative immediate: jal x1, -2048
    jump_imm = -32'sd2048;
    instr = {
      jump_imm[20],
      jump_imm[10:1],
      jump_imm[11],
      jump_imm[19:12],
      5'd1,
      7'b1101111
    };
    #1;
    if (imm_j != 32'hffff_f800) begin
      $display("J-type negative failed: expected 0xfffff800, got %h", imm_j);
      $fatal;
    end

    $display("imm_gen test passed");
    $finish;
  end
endmodule
