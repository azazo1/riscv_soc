`timescale 1ns / 1ps

module spi_master_mmio_vlg_tst;
  reg clk;
  reg rst_n;
  reg req;
  reg we;
  reg [3:0] be;
  reg [31:0] addr;
  reg [31:0] wdata;
  reg spi_miso;
  wire [31:0] rdata;
  wire spi_sclk;
  wire spi_mosi;
  wire spi_cs_n;

  reg [7:0] mosi_seen;
  reg [7:0] miso_data;
  integer i;

  spi_master_mmio dut (
      .clk(clk),
      .rst_n(rst_n),
      .req(req),
      .we(we),
      .be(be),
      .addr(addr),
      .wdata(wdata),
      .rdata(rdata),
      .spi_miso(spi_miso),
      .spi_sclk(spi_sclk),
      .spi_mosi(spi_mosi),
      .spi_cs_n(spi_cs_n)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task expect_value;
    input [31:0] actual;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      if (actual !== expected) begin
        $display("check %0d failed: expected %h, got %h", check_id, expected, actual);
        $fatal;
      end
    end
  endtask

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

  task read_reg;
    input [31:0] read_addr;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      addr = read_addr;
      req = 1'b1;
      we = 1'b0;
      #1;
      expect_value(rdata, expected, check_id);
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
    spi_miso = 1'b1;
    mosi_seen = 8'b0;
    miso_data = 8'h3c;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    #1;

    read_reg(32'h0100_0208, 32'h0000_0001, 32'd1);
    read_reg(32'h0100_020c, 32'h0000_0001, 32'd2);
    read_reg(32'h0100_0210, 32'h0000_0002, 32'd3);

    write_reg(32'h0100_020c, 32'h0000_0000, 4'b0001);
    expect_value({31'b0, spi_cs_n}, 32'h0000_0000, 32'd4);

    write_reg(32'h0100_0210, 32'h0000_0001, 4'b0001);
    read_reg(32'h0100_0210, 32'h0000_0001, 32'd5);

    write_reg(32'h0100_0200, 32'h0000_00a5, 4'b0001);
    #1;
    read_reg(32'h0100_0208, 32'h0000_0002, 32'd6);

    for (i = 7; i >= 0; i = i - 1) begin
      spi_miso = miso_data[i];
      @(posedge spi_sclk);
      mosi_seen[i] = spi_mosi;
      @(negedge spi_sclk);
    end

    repeat (2) @(posedge clk);
    #1;

    expect_value({24'b0, mosi_seen}, 32'h0000_00a5, 32'd7);
    read_reg(32'h0100_0204, 32'h0000_003c, 32'd8);
    read_reg(32'h0100_0208, 32'h0000_0001, 32'd9);
    expect_value({31'b0, spi_sclk}, 32'h0000_0000, 32'd10);

    write_reg(32'h0100_020c, 32'h0000_0001, 4'b0001);
    expect_value({31'b0, spi_cs_n}, 32'h0000_0001, 32'd11);

    $display("spi_master_mmio test passed");
    $finish;
  end
endmodule
