`timescale 1ns / 1ps

module rv32i_soc_snake_app_vlg_tst;
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

  reg [31:0] app_image[0:2047];

  localparam MENU_WORD0 = 16'h0303;
  localparam SELECT_BAR_WORD = 16'hfcfc;

  rv32i_soc #(
      .RESET_PC(32'h0000_8000),
      .ROM_FILE("firmware/test/simple_rom.hex"),
      .UART_CLKS_PER_BIT(4)
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

  sdram_model #(
      .MEM_WORDS(65536),
      .MEM_ADDR_BITS(16)
  ) u_sdram_model (
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

  initial begin
    integer i;
    integer wait_count;
    integer select_bar_word_index;
    integer select_bar_mem_index;

    rst_n = 1'b1;
    sw = 10'h000;
    key = 4'b1111;
    gpio0_in = 36'h0;
    gpio1_in = 36'h0;

    for (i = 0; i < 2048; i = i + 1) begin
      app_image[i] = 32'h0000_0013;
    end
    $readmemh("build/tests/snake_app/snake.hex", app_image);

    for (i = 0; i < 2048; i = i + 1) begin
      dut.u_ram.ram_data[i] = app_image[i];
    end

    #1;
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    select_bar_word_index = 56 * 40 + 17;
    select_bar_mem_index = select_bar_word_index * 2;

    wait_count = 0;
    while ((u_sdram_model.mem[0] !== MENU_WORD0 ||
            u_sdram_model.mem[select_bar_mem_index] !== SELECT_BAR_WORD ||
            ledr[2:0] !== 3'b010) &&
           wait_count < 300000) begin
      wait_count = wait_count + 1;
      @(posedge clk);
    end
    #1;

    expect_value({16'b0, u_sdram_model.mem[0]}, {16'b0, MENU_WORD0}, 32'd1);
    expect_value({16'b0, u_sdram_model.mem[select_bar_mem_index]},
                 {16'b0, SELECT_BAR_WORD}, 32'd2);
    expect_value({29'b0, ledr[2:0]}, 32'h0000_0002, 32'd3);

    $display("rv32i_soc_snake_app test passed");
    $finish;
  end

endmodule
