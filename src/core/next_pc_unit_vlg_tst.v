`timescale 1ns / 1ps

module next_pc_unit_vlg_tst;

  reg [31:0] pc;
  reg [31:0] imm;
  reg [31:0] rs1_data;
  reg branch;
  reg branch_taken;
  reg jump;
  reg is_jalr;
  wire [31:0] next_pc;

  next_pc_unit dut (
      .pc(pc),
      .imm(imm),
      .rs1_data(rs1_data),
      .branch(branch),
      .branch_taken(branch_taken),
      .jump(jump),
      .is_jalr(is_jalr),
      .next_pc(next_pc)
  );

  initial begin
    pc = 32'h0000_1000;
    imm = 32'h0000_0020;
    rs1_data = 32'h0000_2001;
    branch = 1'b0;
    branch_taken = 1'b0;
    jump = 1'b0;
    is_jalr = 1'b0;
    #1;
    if (next_pc != 32'h0000_1004) begin
      $display("default pc+4 failed: got %h", next_pc);
      $fatal;
    end

    branch = 1'b1;
    branch_taken = 1'b0;
    #1;
    if (next_pc != 32'h0000_1004) begin
      $display("branch not taken failed: got %h", next_pc);
      $fatal;
    end

    branch = 1'b1;
    branch_taken = 1'b1;
    #1;
    if (next_pc != 32'h0000_1020) begin
      $display("branch taken failed: got %h", next_pc);
      $fatal;
    end

    branch = 1'b0;
    branch_taken = 1'b0;
    jump = 1'b1;
    is_jalr = 1'b0;
    #1;
    if (next_pc != 32'h0000_1020) begin
      $display("JAL target failed: got %h", next_pc);
      $fatal;
    end

    jump = 1'b1;
    is_jalr = 1'b1;
    rs1_data = 32'h0000_2001;
    imm = 32'h0000_0004;
    #1;
    if (next_pc != 32'h0000_2004) begin
      $display("JALR target clear bit 0 failed: got %h", next_pc);
      $fatal;
    end

    pc = 32'h0000_3000;
    imm = 32'h0000_0040;
    rs1_data = 32'h0000_4003;
    branch = 1'b1;
    branch_taken = 1'b1;
    jump = 1'b1;
    is_jalr = 1'b0;
    #1;
    if (next_pc != 32'h0000_3040) begin
      $display("JAL priority over branch failed: got %h", next_pc);
      $fatal;
    end

    jump = 1'b1;
    is_jalr = 1'b1;
    #1;
    if (next_pc != 32'h0000_4042) begin
      $display("JALR priority over branch failed: got %h", next_pc);
      $fatal;
    end

    $display("next_pc_unit test passed");
    $finish;
  end

endmodule
