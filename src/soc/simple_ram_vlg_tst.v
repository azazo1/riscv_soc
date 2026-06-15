`timescale 1ns / 1ps

module simple_ram_vlg_tst;
  reg clk;
  reg rst_n;
  reg req;
  reg we;
  reg [3:0] be;
  reg [31:0] addr;
  reg [31:0] wdata;
  wire [31:0] rdata;

  simple_ram dut (
      .clk(clk),
      .rst_n(rst_n),
      .req(req),
      .we(we),
      .be(be),
      .addr(addr),
      .wdata(wdata),
      .rdata(rdata)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task write_word;
    input [31:0] write_addr;
    input [31:0] write_data;
    input [3:0] write_be;
    begin
      addr  = write_addr;
      wdata = write_data;
      be    = write_be;
      req   = 1'b1;
      we    = 1'b1;
      @(posedge clk);
      #1;
      req = 1'b0;
      we  = 1'b0;
    end
  endtask

  task expect_read;
    input [31:0] read_addr;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      addr = read_addr;
      req  = 1'b1;
      we   = 1'b0;
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

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    #1;

    write_word(32'h0000_0000, 32'h1122_3344, 4'b1111);
    expect_read(32'h0000_0000, 32'h1122_3344, 32'd1);

    write_word(32'h0000_0004, 32'haabb_ccdd, 4'b1111);
    expect_read(32'h0000_0004, 32'haabb_ccdd, 32'd2);
    expect_read(32'h0000_0000, 32'h1122_3344, 32'd3);

    write_word(32'h0000_0004, 32'h0000_00ee, 4'b0001);
    expect_read(32'h0000_0004, 32'haabb_ccee, 32'd4);

    write_word(32'h0000_0004, 32'h0000_ff00, 4'b0010);
    expect_read(32'h0000_0004, 32'haabb_ffee, 32'd5);

    write_word(32'h0000_0004, 32'h00dd_0000, 4'b0100);
    expect_read(32'h0000_0004, 32'haadd_ffee, 32'd6);

    write_word(32'h0000_0004, 32'h7700_0000, 4'b1000);
    expect_read(32'h0000_0004, 32'h77dd_ffee, 32'd7);

    req = 1'b0;
    we = 1'b0;
    #1;
    if (rdata !== 32'b0) begin
      $display("idle read should return zero: got %h", rdata);
      $fatal;
    end

    $display("simple_ram test passed");
    $finish;
  end
endmodule
