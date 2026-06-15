`timescale 1ns / 1ps

module uart_tx_mmio_vlg_tst;
  reg clk;
  reg rst_n;
  reg req;
  reg we;
  reg [3:0] be;
  reg [31:0] addr;
  reg [31:0] wdata;
  reg tx_ready;
  reg tx_busy;
  wire [31:0] rdata;
  wire tx_valid;
  wire [7:0] tx_data;

  uart_tx_mmio dut (
      .clk(clk),
      .rst_n(rst_n),
      .req(req),
      .we(we),
      .be(be),
      .addr(addr),
      .wdata(wdata),
      .tx_ready(tx_ready),
      .tx_busy(tx_busy),
      .rdata(rdata),
      .tx_valid(tx_valid),
      .tx_data(tx_data)
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

  initial begin
    rst_n = 1'b0;
    req = 1'b0;
    we = 1'b0;
    be = 4'b0000;
    addr = 32'b0;
    wdata = 32'b0;
    tx_ready = 1'b1;
    tx_busy = 1'b0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    #1;

    expect_value({31'b0, tx_valid}, 32'b0, 32'd1);
    expect_value({24'b0, tx_data}, 32'h0000_0000, 32'd2);
    read_reg(32'h0100_0104, 32'h0000_0001, 32'd3);

    write_reg(32'h0100_0100, 32'h0000_0055, 4'b0001);
    expect_value({31'b0, tx_valid}, 32'h0000_0001, 32'd4);
    expect_value({24'b0, tx_data}, 32'h0000_0055, 32'd5);

    @(posedge clk);
    #1;
    expect_value({31'b0, tx_valid}, 32'h0000_0000, 32'd6);
    read_reg(32'h0100_0100, 32'h0000_0055, 32'd7);

    tx_ready = 1'b0;
    tx_busy = 1'b1;
    read_reg(32'h0100_0104, 32'h0000_0002, 32'd8);
    write_reg(32'h0100_0100, 32'h0000_00aa, 4'b0001);
    expect_value({31'b0, tx_valid}, 32'h0000_0000, 32'd9);
    expect_value({24'b0, tx_data}, 32'h0000_0055, 32'd10);

    tx_ready = 1'b1;
    tx_busy = 1'b0;
    write_reg(32'h0100_0100, 32'h0000_00aa, 4'b0010);
    expect_value({31'b0, tx_valid}, 32'h0000_0000, 32'd11);
    expect_value({24'b0, tx_data}, 32'h0000_0055, 32'd12);

    read_reg(32'h0100_0200, 32'h0000_0000, 32'd13);

    $display("uart_tx_mmio test passed");
    $finish;
  end
endmodule
