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
  reg [35:0] gpio0_in;
  reg [35:0] gpio1_in;

  wire [31:0] rdata;
  wire [9:0] ledr;
  wire [6:0] hex0;
  wire [6:0] hex1;
  wire [6:0] hex2;
  wire [6:0] hex3;
  wire [6:0] hex4;
  wire [6:0] hex5;
  wire [35:0] gpio0_out;
  wire [35:0] gpio0_oe;
  wire [35:0] gpio1_out;
  wire [35:0] gpio1_oe;

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
      .gpio0_in(gpio0_in),
      .gpio1_in(gpio1_in),
      .rdata(rdata),
      .ledr(ledr),
      .hex0(hex0),
      .hex1(hex1),
      .hex2(hex2),
      .hex3(hex3),
      .hex4(hex4),
      .hex5(hex5),
      .gpio0_out(gpio0_out),
      .gpio0_oe(gpio0_oe),
      .gpio1_out(gpio1_out),
      .gpio1_oe(gpio1_oe)
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
    gpio0_in = 36'hf_1234_5678;
    gpio1_in = 36'h5_dead_beef;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    #1;

    if (ledr !== 10'b0 || hex0 !== 7'h7f || hex5 !== 7'h7f || gpio0_out !== 36'b0 || gpio0_oe !== 36'b0 || gpio1_out !== 36'b0 || gpio1_oe !== 36'b0) begin
      $display("reset output failed");
      $fatal;
    end

    expect_read(32'h0100_0004, {22'b0, sw}, 32'd1);
    expect_read(32'h0100_0008, {28'b0, key}, 32'd2);

    write_reg(32'h0100_0000, 32'h0000_0155, 4'b0011);
    expect_read(32'h0100_0000, 32'h0000_0155, 32'd3);

    write_reg(32'h0100_0000, 32'h0000_0200, 4'b0010);
    expect_read(32'h0100_0000, 32'h0000_0255, 32'd4);

    write_reg(32'h0100_000c, 32'h3f_06_5b_4f, 4'b1111);
    expect_read(32'h0100_000c, 32'h3f_06_5b_4f, 32'd5);

    write_reg(32'h0100_0010, 32'h66_6d_7d_07, 4'b1111);
    expect_read(32'h0100_0010, 32'h0000_7d07, 32'd6);

    write_reg(32'h0100_0010, 32'h00_00_12_19, 4'b1100);
    expect_read(32'h0100_0010, 32'h0000_7d07, 32'd7);

    write_reg(32'h0100_000c, 32'h00_00_00_40, 4'b0001);
    expect_read(32'h0100_000c, 32'h3f_06_5b_40, 32'd8);

    expect_read(32'h0100_0020, 32'h1234_5678, 32'd9);
    expect_read(32'h0100_0024, 32'h0000_000f, 32'd10);
    expect_read(32'h0100_0040, 32'hdead_beef, 32'd11);
    expect_read(32'h0100_0044, 32'h0000_0005, 32'd12);

    write_reg(32'h0100_0028, 32'h89ab_cdef, 4'b1111);
    write_reg(32'h0100_002c, 32'h0000_000a, 4'b0001);
    expect_read(32'h0100_0028, 32'h89ab_cdef, 32'd13);
    expect_read(32'h0100_002c, 32'h0000_000a, 32'd14);
    expect_read(32'h0100_0020, 32'h1234_5678, 32'd15);

    write_reg(32'h0100_0030, 32'hffff_000f, 4'b1111);
    write_reg(32'h0100_0034, 32'h0000_0003, 4'b0001);
    expect_read(32'h0100_0030, 32'hffff_000f, 32'd16);
    expect_read(32'h0100_0034, 32'h0000_0003, 32'd17);

    write_reg(32'h0100_0048, 32'h1357_9bdf, 4'b1111);
    write_reg(32'h0100_004c, 32'h0000_000c, 4'b0001);
    expect_read(32'h0100_0048, 32'h1357_9bdf, 32'd18);
    expect_read(32'h0100_004c, 32'h0000_000c, 32'd19);

    write_reg(32'h0100_0050, 32'h0f0f_f0f0, 4'b1111);
    write_reg(32'h0100_0054, 32'h0000_0006, 4'b0001);
    expect_read(32'h0100_0050, 32'h0f0f_f0f0, 32'd20);
    expect_read(32'h0100_0054, 32'h0000_0006, 32'd21);

    req = 1'b0;
    we = 1'b0;
    addr = 32'h0100_0000;
    #1;
    if (rdata !== 32'b0) begin
      $display("idle read should return zero: got %h", rdata);
      $fatal;
    end

    $display("gpio_mmio test passed");
    $finish;
  end
endmodule
