`timescale 1ns / 1ps

module uart_tx_vlg_tst;
  reg clk;
  reg rst_n;
  reg tx_valid;
  reg [7:0] tx_data;
  wire tx_ready;
  wire tx_busy;
  wire uart_tx_pin;

  uart_tx #(
      .CLKS_PER_BIT(4)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .tx_valid(tx_valid),
      .tx_data(tx_data),
      .tx_ready(tx_ready),
      .tx_busy(tx_busy),
      .uart_tx(uart_tx_pin)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task expect_bit;
    input actual;
    input expected;
    input [31:0] check_id;
    begin
      if (actual !== expected) begin
        $display("check %0d failed: expected %b, got %b", check_id, expected, actual);
        $fatal;
      end
    end
  endtask

  initial begin
    rst_n = 1'b0;
    tx_valid = 1'b0;
    tx_data = 8'h00;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    #1;

    expect_bit(uart_tx_pin, 1'b1, 32'd1);
    expect_bit(tx_ready, 1'b1, 32'd2);
    expect_bit(tx_busy, 1'b0, 32'd3);

    tx_data = 8'ha5;
    tx_valid = 1'b1;
    @(posedge clk);
    #1;
    tx_valid = 1'b0;

    expect_bit(uart_tx_pin, 1'b0, 32'd4);
    expect_bit(tx_ready, 1'b0, 32'd5);
    expect_bit(tx_busy, 1'b1, 32'd6);

    repeat (4) @(posedge clk);
    #1;
    expect_bit(uart_tx_pin, 1'b1, 32'd7);

    repeat (4) @(posedge clk);
    #1;
    expect_bit(uart_tx_pin, 1'b0, 32'd8);

    repeat (4) @(posedge clk);
    #1;
    expect_bit(uart_tx_pin, 1'b1, 32'd9);

    repeat (4) @(posedge clk);
    #1;
    expect_bit(uart_tx_pin, 1'b0, 32'd10);

    repeat (4) @(posedge clk);
    #1;
    expect_bit(uart_tx_pin, 1'b0, 32'd11);

    repeat (4) @(posedge clk);
    #1;
    expect_bit(uart_tx_pin, 1'b1, 32'd12);

    repeat (4) @(posedge clk);
    #1;
    expect_bit(uart_tx_pin, 1'b0, 32'd13);

    repeat (4) @(posedge clk);
    #1;
    expect_bit(uart_tx_pin, 1'b1, 32'd14);

    repeat (4) @(posedge clk);
    #1;
    expect_bit(uart_tx_pin, 1'b1, 32'd15);

    repeat (4) @(posedge clk);
    #1;
    expect_bit(uart_tx_pin, 1'b1, 32'd16);
    expect_bit(tx_ready, 1'b1, 32'd17);
    expect_bit(tx_busy, 1'b0, 32'd18);

    $display("uart_tx test passed");
    $finish;
  end
endmodule
