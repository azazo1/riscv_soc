`timescale 1ns / 1ps

module rv32i_soc_soft_float_vlg_tst;
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
  wire spi_sclk;
  wire spi_mosi;
  wire spi_cs_n;

  reg [31:0] app_image[0:1023];

  rv32i_soc #(
      .RESET_PC(32'h0000_8000),
      .ROM_FILE("firmware/test/simple_rom.hex")
  ) dut (
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
      .uart_tx_pin(uart_tx_pin),
      .spi_miso(1'b1),
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

  initial begin
    integer i;

    rst_n = 1'b1;
    sw = 10'h000;
    key = 4'b1111;
    gpio0_in = 36'h0;
    gpio1_in = 36'h0;

    for (i = 0; i < 1024; i = i + 1) begin
      app_image[i] = 32'h0000_0013;
    end
    $readmemh("build/tests/soft_float_test/soft_float_test.hex", app_image);

    for (i = 0; i < 1024; i = i + 1) begin
      dut.u_ram.ram_data[i] = app_image[i];
    end

    #1;
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    repeat (6000) @(posedge clk);
    #1;

    expect_value({22'b0, ledr}, 32'h0000_0015, 32'd1);

    $display("rv32i_soc_soft_float test passed");
    $finish;
  end
endmodule
