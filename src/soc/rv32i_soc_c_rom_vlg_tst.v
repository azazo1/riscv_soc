`timescale 1ns / 1ps

module rv32i_soc_c_rom_vlg_tst;
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
  wire [12:0] sdram_addr;
  wire [1:0] sdram_ba;
  wire sdram_cas_n;
  wire sdram_cke;
  wire sdram_clk;
  wire sdram_cs_n;
  wire [15:0] sdram_dq;
  wire sdram_ldqm;
  wire sdram_ras_n;
  wire sdram_udqm;
  wire sdram_we_n;

  localparam TEST_CLKS_PER_BIT = 4;

  rv32i_soc #(
      .ROM_FILE("firmware/c_demo/c_demo.hex"),
      .UART_CLKS_PER_BIT(TEST_CLKS_PER_BIT)
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
      .spi_cs_n(spi_cs_n),
      .sdram_addr(sdram_addr),
      .sdram_ba(sdram_ba),
      .sdram_cas_n(sdram_cas_n),
      .sdram_cke(sdram_cke),
      .sdram_clk(sdram_clk),
      .sdram_cs_n(sdram_cs_n),
      .sdram_dq(sdram_dq),
      .sdram_ldqm(sdram_ldqm),
      .sdram_ras_n(sdram_ras_n),
      .sdram_udqm(sdram_udqm),
      .sdram_we_n(sdram_we_n)
  );

  sdram_model u_sdram_model (
      .clk(sdram_clk),
      .sdram_addr(sdram_addr),
      .sdram_ba(sdram_ba),
      .sdram_cs_n(sdram_cs_n),
      .sdram_cke(sdram_cke),
      .sdram_ras_n(sdram_ras_n),
      .sdram_cas_n(sdram_cas_n),
      .sdram_we_n(sdram_we_n),
      .sdram_dqm({sdram_udqm, sdram_ldqm}),
      .sdram_dq(sdram_dq)
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

  task expect_uart_byte;
    input [7:0] expected;
    input [31:0] check_id;
    integer bit_index;
    reg [7:0] actual;
    begin
      actual = 8'b0;

      while (uart_tx_pin !== 1'b0) begin
        @(posedge clk);
      end

      repeat (TEST_CLKS_PER_BIT) @(posedge clk);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        actual[bit_index] = uart_tx_pin;
        repeat (TEST_CLKS_PER_BIT) @(posedge clk);
      end

      if (actual !== expected) begin
        $display("check %0d failed: expected byte %h, got %h", check_id, expected, actual);
        $fatal;
      end

      if (uart_tx_pin !== 1'b1) begin
        $display("check %0d failed: stop bit is not high", check_id);
        $fatal;
      end

      repeat (TEST_CLKS_PER_BIT) @(posedge clk);
    end
  endtask

  initial begin
    rst_n = 1'b1;
    sw = 10'h000;
    key = 4'b1111;
    gpio0_in = 36'h0;
    gpio1_in = 36'h0;

    #1;
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    expect_uart_byte(8'h43, 32'd1);
    expect_uart_byte(8'h20, 32'd2);
    expect_uart_byte(8'h64, 32'd3);
    expect_uart_byte(8'h65, 32'd4);
    expect_uart_byte(8'h6d, 32'd5);
    expect_uart_byte(8'h6f, 32'd6);
    expect_uart_byte(8'h0a, 32'd7);
    expect_value({22'b0, ledr}, 32'h0000_0001, 32'd8);

    key = 4'b1110;
    expect_uart_byte(8'h4b, 32'd9);
    expect_uart_byte(8'h65, 32'd10);
    expect_uart_byte(8'h0a, 32'd11);
    expect_value({22'b0, ledr}, 32'h0000_0003, 32'd12);

    $display("rv32i_soc_c_rom test passed");
    $finish;
  end
endmodule
