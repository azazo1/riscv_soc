`timescale 1ns / 1ps  // #5 的尺度 / 仿真精度

module regfile_vlg_tst;
  reg clk;
  reg rst_n;
  reg [4:0] rs1_addr;
  reg [4:0] rs2_addr;
  wire [31:0] rs1_data;
  wire [31:0] rs2_data;

  reg rd_we;
  reg [4:0] rd_addr;
  reg [31:0] rd_data;

  regfile dut (
      .clk(clk),
      .rst_n(rst_n),
      .rs1_addr(rs1_addr),
      .rs2_addr(rs2_addr),
      .rs1_data(rs1_data),
      .rs2_data(rs2_data),
      .rd_we(rd_we),
      .rd_addr(rd_addr),
      .rd_data(rd_data)
  );

  // 100MHz clock
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;  // 5ns
  end

  initial begin
    rst_n = 1'b0;
    rs1_addr = 5'd0;
    rs2_addr = 5'd0;
    rd_we = 1'b0;
    rd_addr = 5'd0;
    rd_data = 32'd0;

    // 复位有效一会
    #20;
    rst_n = 1'b1;

    // read x1 after reset, should be zero.
    rs1_addr = 5'b1;
    #1;
    if (rs1_data != 32'b0) begin // 读取寄存器内容的时候是直接 assign 的, 不需要等待时钟.
      $display("x1 should be zero after reset");
      $fatal;
    end

    // write x1, then read it from rs1.
    rd_we   = 1'b1;
    rd_addr = 5'b1;
    rd_data = 32'h12345678;
    @(posedge clk);
    #1;
    rd_we = 1'b0;

    rs1_addr = 5'b1;
    #1;
    if (rs1_data != 32'h12345678) begin
      $display("x1 should be 32'h12345678 after writing it");
      $fatal;
    end

    // write x2, then read it from rs2.
    rd_we   = 1'b1;
    rd_addr = 5'd2;
    rd_data = 32'h87654321;
    @(posedge clk);
    #1;
    rd_we = 1'b0;

    rs2_addr = 5'd2;
    #1;
    if (rs2_data != 32'h87654321) begin
      $display("x2 should be 32'h87654321 after writing it");
      $fatal;
    end

    // try to write x0, then read x0, it should still be zero.
    rd_we   = 1'b1;
    rd_addr = 5'd0;
    rd_data = 32'hA5A5A5A5;
    @(posedge clk);
    #1;
    rd_we = 1'b0;

    rs1_addr = 5'd0;
    #1;
    if (rs1_data != 32'h0) begin
      $display("x0 should be 32'h0 after writing it");
      $fatal;
    end

    $display("regfile test passed");
    $finish;

  end
endmodule
