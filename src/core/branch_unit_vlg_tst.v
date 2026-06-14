`timescale 1ns / 1ps

module branch_unit_vlg_tst;

  reg [2:0] funct3;
  reg [31:0] lhs;
  reg [31:0] rhs;
  wire branch_taken;

  localparam BR_BEQ  = 3'b000;
  localparam BR_BNE  = 3'b001;
  localparam BR_BLT  = 3'b100;
  localparam BR_BGE  = 3'b101;
  localparam BR_BLTU = 3'b110;
  localparam BR_BGEU = 3'b111;

  branch_unit dut (
      .funct3(funct3),
      .lhs(lhs),
      .rhs(rhs),
      .branch_taken(branch_taken)
  );

  initial begin
    funct3 = BR_BEQ;
    lhs = 32'h1234_5678;
    rhs = 32'h1234_5678;
    #1;
    if (!branch_taken) begin
      $display("BEQ equal failed");
      $fatal;
    end

    funct3 = BR_BEQ;
    lhs = 32'h1234_5678;
    rhs = 32'h8765_4321;
    #1;
    if (branch_taken) begin
      $display("BEQ not equal failed");
      $fatal;
    end

    funct3 = BR_BNE;
    lhs = 32'h1234_5678;
    rhs = 32'h8765_4321;
    #1;
    if (!branch_taken) begin
      $display("BNE not equal failed");
      $fatal;
    end

    funct3 = BR_BNE;
    lhs = 32'h1234_5678;
    rhs = 32'h1234_5678;
    #1;
    if (branch_taken) begin
      $display("BNE equal failed");
      $fatal;
    end

    // Signed compare: 0xffffffff is -1, so -1 < 1.
    funct3 = BR_BLT;
    lhs = 32'hffff_ffff;
    rhs = 32'h0000_0001;
    #1;
    if (!branch_taken) begin
      $display("BLT signed negative failed");
      $fatal;
    end

    funct3 = BR_BGE;
    lhs = 32'hffff_ffff;
    rhs = 32'h0000_0001;
    #1;
    if (branch_taken) begin
      $display("BGE signed negative failed");
      $fatal;
    end

    funct3 = BR_BGE;
    lhs = 32'h0000_0001;
    rhs = 32'hffff_ffff;
    #1;
    if (!branch_taken) begin
      $display("BGE signed positive failed");
      $fatal;
    end

    // Unsigned compare: 0xffffffff is larger than 1.
    funct3 = BR_BLTU;
    lhs = 32'hffff_ffff;
    rhs = 32'h0000_0001;
    #1;
    if (branch_taken) begin
      $display("BLTU unsigned high failed");
      $fatal;
    end

    funct3 = BR_BGEU;
    lhs = 32'hffff_ffff;
    rhs = 32'h0000_0001;
    #1;
    if (!branch_taken) begin
      $display("BGEU unsigned high failed");
      $fatal;
    end

    funct3 = BR_BLTU;
    lhs = 32'h0000_0001;
    rhs = 32'hffff_ffff;
    #1;
    if (!branch_taken) begin
      $display("BLTU unsigned low failed");
      $fatal;
    end

    funct3 = 3'b010;
    lhs = 32'h0000_0000;
    rhs = 32'h0000_0000;
    #1;
    if (branch_taken) begin
      $display("Invalid branch funct3 failed");
      $fatal;
    end

    $display("branch_unit test passed");
    $finish;
  end

endmodule
