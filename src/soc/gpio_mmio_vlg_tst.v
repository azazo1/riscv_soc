`timescale 1ns / 1ps

module gpio_mmio_vlg_tst;
  reg clk;
  reg rst_n;
  reg req;
  reg we;
  reg [3:0] be;
  reg [31:0] addr;
  reg [31:0] wdata;
  reg [9:0] sw;
  reg [3:0] key;

  wire [31:0] rdata;
  wire [9:0] ledr;
  wire [6:0] hex0;
  wire [6:0] hex1;
  wire [6:0] hex2;
  wire [6:0] hex3;
  wire [6:0] hex4;
  wire [6:0] hex5;
  wire [6:0] hex6;
  wire [6:0] hex7;

  gpio_mmio dut (
      .clk(clk),
      .rst_n(rst_n),
      .req(req),
      .we(we),
      .be(be),
      .addr(addr),
      .wdata(wdata),
      .sw(sw),
      .key(key),
      .rdata(rdata),
      .ledr(ledr),
      .hex0(hex0),
      .hex1(hex1),
      .hex2(hex2),
      .hex3(hex3),
      .hex4(hex4),
      .hex5(hex5),
      .hex6(hex6),
      .hex7(hex7)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task write_reg;
    input [31:0] write_addr;
    input [31:0] write_data;
    input [3:0] write_be;
    begin
      addr = write_addr;
      wdata = write_data;
      be = write_be;
      req = 1'b1;
      we = 1'b1;
      @(posedge clk);
      #1;
      req = 1'b0;
      we = 1'b0;
    end
  endtask

  task expect_read;
    input [31:0] read_addr;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      addr = read_addr;
      req = 1'b1;
      we = 1'b0;
      #1;
      if (rdata !== expected) begin
        $display("check %0d failed at addr %h: expected %h, got %h", check_id, read_addr, expected, rdata);
        $fatal;
      end
      req = 1'b0;
    end
  endtask

  initial begin
    rst_n = 1'b0;
    req = 1'b0;
    we = 1'b0;
    be = 4'b0000;
    addr = 32'b0;
    wdata = 32'b0;
    sw = 10'b10_1100_0011;
    key = 4'b1010;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    #1;

    if (ledr !== 10'b0 || hex0 !== 7'h7f || hex7 !== 7'h7f) begin
      $display("reset output failed: ledr=%b hex0=%b hex7=%b", ledr, hex0, hex7);
      $fatal;
    end

    expect_read(32'h1000_0004, {22'b0, sw}, 32'd1);
    expect_read(32'h1000_0008, {28'b0, key}, 32'd2);

    write_reg(32'h1000_0000, 32'h0000_0155, 4'b0011);
    expect_read(32'h1000_0000, 32'h0000_0155, 32'd3);

    write_reg(32'h1000_0000, 32'h0000_0200, 4'b0010);
    expect_read(32'h1000_0000, 32'h0000_0255, 32'd4);

    write_reg(32'h1000_000c, 32'h3f_06_5b_4f, 4'b1111);
    expect_read(32'h1000_000c, 32'h3f_06_5b_4f, 32'd5);

    write_reg(32'h1000_0010, 32'h66_6d_7d_07, 4'b1111);
    expect_read(32'h1000_0010, 32'h66_6d_7d_07, 32'd6);

    write_reg(32'h1000_000c, 32'h00_00_00_40, 4'b0001);
    expect_read(32'h1000_000c, 32'h3f_06_5b_40, 32'd7);

    req = 1'b0;
    we = 1'b0;
    addr = 32'h1000_0000;
    #1;
    if (rdata !== 32'b0) begin
      $display("idle read should return zero: got %h", rdata);
      $fatal;
    end

    $display("gpio_mmio test passed");
    $finish;
  end
endmodule
