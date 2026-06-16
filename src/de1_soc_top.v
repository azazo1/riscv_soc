`timescale 1ns / 1ps

// 适用于 de1_soc 的顶层模块, 用于在 quartus 中直接编译.
module de1_soc_top #(
    parameter ROM_FILE = "firmware/bootloader/bootloader.hex"
) (
    input wire clk,

    input  wire [9:0] sw,
    input  wire [3:0] key,
    output wire [9:0] ledr,
    output wire [6:0] hex0,
    output wire [6:0] hex1,
    output wire [6:0] hex2,
    output wire [6:0] hex3,
    output wire [6:0] hex4,
    output wire [6:0] hex5,

    inout wire [35:0] gpio0,
    // 实机上, gpio1[0] 位于右侧 40 针脚中的最左上的针脚.
    inout wire [35:0] gpio1,

    output wire [12:0] dram_addr,
    output wire [1:0] dram_ba,
    output wire dram_cas_n,
    output wire dram_cke,
    output wire dram_clk,
    output wire dram_cs_n,
    inout wire [15:0] dram_dq,
    output wire dram_ldqm,
    output wire dram_ras_n,
    output wire dram_udqm,
    output wire dram_we_n,

    output wire [7:0] vga_r,
    output wire [7:0] vga_g,
    output wire [7:0] vga_b,
    output wire vga_hs,
    output wire vga_vs,
    output wire vga_blank_n,
    output wire vga_sync_n,
    output wire vga_clk
);

  wire [35:0] gpio0_out;
  wire [35:0] gpio0_oe;
  wire [35:0] gpio1_out;
  wire [35:0] gpio1_oe;
  wire uart_tx_pin;
  wire spi_sclk;
  wire spi_mosi;
  wire spi_cs_n;
  wire spi_miso;

  genvar i;
  generate
    for (i = 0; i < 36; i = i + 1) begin : gen_gpio0
      assign gpio0[i] = gpio0_oe[i] ? gpio0_out[i] : 1'bz;
    end

    for (i = 5; i < 36; i = i + 1) begin : gen_gpio1
      assign gpio1[i] = gpio1_oe[i] ? gpio1_out[i] : 1'bz;
    end
  endgenerate

  // GPIO_1[0] 暂时作为 UART TX 使用, 接到 USB-TTL 的 RX.
  assign gpio1[0] = uart_tx_pin;
  // GPIO_1[1..4] 暂时作为外接 SPI SD 模块使用.
  assign gpio1[1] = spi_sclk;
  assign gpio1[2] = spi_mosi;
  assign gpio1[3] = spi_cs_n;
  assign gpio1[4] = 1'bz;
  assign spi_miso = gpio1[4];

  rv32i_soc #(
      .ROM_FILE(ROM_FILE)
  ) u_soc (
      .clk(clk),
      .rst_n(~sw[9]),  // 使用 SW9 作为板级复位, SW9=1 时内部 rst_n=0.
      .sw(sw),
      .key(key),
      .ledr(ledr),
      .hex0(hex0),
      .hex1(hex1),
      .hex2(hex2),
      .hex3(hex3),
      .hex4(hex4),
      .hex5(hex5),
      .gpio0_in(gpio0),
      .gpio1_in(gpio1),
      .gpio0_out(gpio0_out),
      .gpio0_oe(gpio0_oe),
      .gpio1_out(gpio1_out),
      .gpio1_oe(gpio1_oe),
      .uart_tx_pin(uart_tx_pin),
      .spi_miso(spi_miso),
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
      .sdram_addr(dram_addr),
      .sdram_ba(dram_ba),
      .sdram_cas_n(dram_cas_n),
      .sdram_cke(dram_cke),
      .sdram_clk(dram_clk),
      .sdram_cs_n(dram_cs_n),
      .sdram_dq(dram_dq),
      .sdram_ldqm(dram_ldqm),
      .sdram_ras_n(dram_ras_n),
      .sdram_udqm(dram_udqm),
      .sdram_we_n(dram_we_n)
  );

endmodule
