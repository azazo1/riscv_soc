`timescale 1ns / 1ps

module rv32i_soc_selfsale_rom_vlg_tst;
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
  wire [7:0] vga_r;
  wire [7:0] vga_g;
  wire [7:0] vga_b;
  wire vga_hs;
  wire vga_vs;
  wire vga_blank_n;
  wire vga_sync_n;
  wire vga_clk;
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

  rv32i_soc #(
      .ROM_FILE("build/tests/selfsale/selfsale.hex")
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
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .vga_hs(vga_hs),
      .vga_vs(vga_vs),
      .vga_blank_n(vga_blank_n),
      .vga_sync_n(vga_sync_n),
      .vga_clk(vga_clk),
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

  task wait_led;
    input [9:0] expected;
    input [31:0] check_id;
    integer i;
    begin
      i = 0;
      while (ledr !== expected && i < 4000) begin
        i = i + 1;
        @(posedge clk);
      end

      if (ledr !== expected) begin
        $display("check %0d failed: expected LEDR %h, got %h", check_id, expected, ledr);
        $fatal;
      end
    end
  endtask

  task press_key;
    input [3:0] low_mask;
    begin
      key = 4'b1111 & (~low_mask);
      repeat (5000) @(posedge clk);
      key = 4'b1111;
      repeat (5000) @(posedge clk);
    end
  endtask

  task expect_hex_digits;
    input [6:0] e0;
    input [6:0] e1;
    input [6:0] e2;
    input [6:0] e3;
    input [6:0] e4;
    input [6:0] e5;
    input [31:0] check_id;
    begin
      if (hex0 !== e0 || hex1 !== e1 || hex2 !== e2 || hex3 !== e3 || hex4 !== e4 || hex5 !== e5) begin
        $display("check %0d failed: hex got %h %h %h %h %h %h", check_id, hex5, hex4, hex3, hex2, hex1, hex0);
        $fatal;
      end
    end
  endtask

  task wait_hex_digits;
    input [6:0] e0;
    input [6:0] e1;
    input [6:0] e2;
    input [6:0] e3;
    input [6:0] e4;
    input [6:0] e5;
    input [31:0] check_id;
    integer i;
    begin
      i = 0;
      while ((hex0 !== e0 || hex1 !== e1 || hex2 !== e2 || hex3 !== e3 || hex4 !== e4 || hex5 !== e5) && i < 8000) begin
        i = i + 1;
        @(posedge clk);
      end

      expect_hex_digits(e0, e1, e2, e3, e4, e5, check_id);
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

    wait_hex_digits(7'h40, 7'h40, 7'h40, 7'h40, 7'h40, 7'h40, 32'd2);
    expect_value({22'b0, ledr}, 32'h0000_0000, 32'd1);

    sw[0] = 1'b1;
    wait_led(10'h200, 32'd3);
    wait_hex_digits(7'h40, 7'h40, 7'h40, 7'h40, 7'h40, 7'h40, 32'd4);

    press_key(4'b0001);
    wait_led(10'h201, 32'd5);
    wait_hex_digits(7'h40, 7'h40, 7'h10, 7'h40, 7'h40, 7'h40, 32'd6);

    press_key(4'b0100);
    wait_led(10'h201, 32'd7);
    wait_hex_digits(7'h12, 7'h40, 7'h10, 7'h40, 7'h79, 7'h40, 32'd8);

    press_key(4'b1000);
    wait_led(10'h200, 32'd9);
    wait_hex_digits(7'h02, 7'h40, 7'h40, 7'h40, 7'h24, 7'h40, 32'd10);

    sw[0] = 1'b0;
    wait_led(10'h000, 32'd11);
    wait_hex_digits(7'h40, 7'h40, 7'h40, 7'h40, 7'h40, 7'h40, 32'd12);

    $display("rv32i_soc_selfsale_rom test passed");
    $finish;
  end
endmodule
