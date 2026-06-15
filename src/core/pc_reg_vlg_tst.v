`timescale 1ns / 1ps

module pc_reg_vlg_tst;

  reg clk;
  reg rst_n;
  reg hold;
  reg [31:0] next_pc;
  wire [31:0] pc;

  localparam RESET_PC = 32'h8000_0000;

  pc_reg #(
      .RESET_PC(RESET_PC)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .hold(hold),
      .next_pc(next_pc),
      .pc(pc)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 1'b1;
    hold = 1'b0;
    next_pc = 32'h0000_1000;
    #1;
    rst_n = 1'b0;
    #1;
    if (pc != RESET_PC) begin
      $display("reset pc failed: expected %h, got %h", RESET_PC, pc);
      $fatal;
    end

    @(posedge clk);
    #1;
    if (pc != RESET_PC) begin
      $display("pc should stay reset while rst_n is low: got %h", pc);
      $fatal;
    end

    rst_n = 1'b1;
    next_pc = 32'h0000_1004;
    @(posedge clk);
    #1;
    if (pc != 32'h0000_1004) begin
      $display("pc update 1 failed: got %h", pc);
      $fatal;
    end

    hold = 1'b1;
    next_pc = 32'h0000_1008;
    @(posedge clk);
    #1;
    if (pc != 32'h0000_1004) begin
      $display("pc hold failed: got %h", pc);
      $fatal;
    end

    hold = 1'b0;
    @(posedge clk);
    #1;
    if (pc != 32'h0000_1008) begin
      $display("pc update 2 failed: got %h", pc);
      $fatal;
    end

    rst_n = 1'b0;
    #1;
    if (pc != RESET_PC) begin
      $display("async reset after updates failed: got %h", pc);
      $fatal;
    end

    $display("pc_reg test passed");
    $finish;
  end

endmodule
