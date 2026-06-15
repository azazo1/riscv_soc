`timescale 1ns / 1ps

module rv32i_soc_vlg_tst;
  reg clk;
  reg rst_n;
  reg [9:0] sw;
  reg [3:0] key;
  wire [9:0] ledr;
  wire [6:0] hex0;
  wire [6:0] hex1;
  wire [6:0] hex2;
  wire [6:0] hex3;
  wire [6:0] hex4;
  wire [6:0] hex5;
  reg [35:0] gpio0_in;
  reg [35:0] gpio1_in;
  wire [35:0] gpio0_out;
  wire [35:0] gpio0_oe;
  wire [35:0] gpio1_out;
  wire [35:0] gpio1_oe;
  wire uart_tx_pin;

  rv32i_soc dut (
      .clk(clk),
      .rst_n(rst_n),
      .sw(sw),
      .key(key),
      .ledr(ledr),
      .hex0(hex0),
      .hex1(hex1),
      .hex2(hex2),
      .hex3(hex3),
      .hex4(hex4),
      .hex5(hex5),
      .gpio0_in(gpio0_in),
      .gpio1_in(gpio1_in),
      .gpio0_out(gpio0_out),
      .gpio0_oe(gpio0_oe),
      .gpio1_out(gpio1_out),
      .gpio1_oe(gpio1_oe),
      .uart_tx_pin(uart_tx_pin)
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

  initial begin
    rst_n = 1'b1;
    sw = 10'h2a5;
    key = 4'b1111;
    gpio0_in = 36'h0;
    gpio1_in = 36'h0;
    #1;
    rst_n = 1'b0;
    #20;
    rst_n = 1'b1;

    repeat (120) @(posedge clk);
    #1;

    expect_value({22'b0, ledr}, 32'h0000_000f, 32'd1);
    expect_value(dut.u_core.u_regfile.regs[30], 32'h0000_0000, 32'd2);
    expect_value(dut.u_core.u_regfile.regs[31], 32'h0000_000f, 32'd3);
    expect_value(dut.u_ram.ram_data[32], 32'h1234_5678, 32'd4);
    expect_value({1'b0, hex3, 1'b0, hex2, 1'b0, hex1, 1'b0, hex0}, 32'h7f7f_7f40, 32'd5);
    expect_value({16'b0, 1'b0, hex5, 1'b0, hex4}, 32'h0000_7f7f, 32'd6);
    expect_value(gpio0_out[31:0], 32'h0000_0000, 32'd7);
    expect_value(gpio0_oe[31:0], 32'h0000_0000, 32'd8);
    expect_value(gpio1_out[31:0], 32'h0000_0000, 32'd9);
    expect_value(gpio1_oe[31:0], 32'h0000_0000, 32'd10);
    expect_value({31'b0, uart_tx_pin}, 32'h0000_0001, 32'd11);

    $display("rv32i_soc test passed");
    $finish;
  end
endmodule
