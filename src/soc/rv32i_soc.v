`timescale 1ns / 1ps

// 简单 soc 实现
module rv32i_soc #(
    parameter RESET_PC = 32'h0000_0000,
    parameter ROM_FILE = "firmware/board_demo/board_demo.hex",
    // UART_CLKS_PER_BIT = clk_hz / baud, example: 50 MHz / 115200 ~= 434.
    parameter UART_CLKS_PER_BIT = 434
) (
    input wire clk,
    input wire rst_n,

    // gpio
    input  wire [9:0] sw,
    input  wire [3:0] key,
    output wire [9:0] ledr,
    output wire [6:0] hex0,
    output wire [6:0] hex1,
    output wire [6:0] hex2,
    output wire [6:0] hex3,
    output wire [6:0] hex4,
    output wire [6:0] hex5,

    // de1-soc gpio header, only FPGA IO pins are exposed here.
    input wire [35:0] gpio0_in,
    input wire [35:0] gpio1_in,
    output wire [35:0] gpio0_out,
    output wire [35:0] gpio0_oe,
    output wire [35:0] gpio1_out,
    output wire [35:0] gpio1_oe,

    // uart tx
    output wire uart_tx_pin,

    // spi, for external sd card module in spi mode.
    input wire spi_miso,
    output wire spi_sclk,
    output wire spi_mosi,
    output wire spi_cs_n
);

  wire dmem_req;
  wire dmem_we;
  wire [3:0] dmem_be;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  wire [31:0] dmem_rdata;

  wire ram_req;
  wire ram_we;
  wire [3:0] ram_be;
  wire [31:0] ram_addr;
  wire [31:0] ram_wdata;
  wire [31:0] ram_rdata;

  wire rom_req;
  wire [31:0] rom_addr;
  wire [31:0] rom_rdata;

  wire gpio_req;
  wire gpio_we;
  wire [3:0] gpio_be;
  wire [31:0] gpio_addr;
  wire [31:0] gpio_wdata;
  wire [31:0] gpio_rdata;

  wire uart_req;
  wire uart_we;
  wire [3:0] uart_be;
  wire [31:0] uart_addr;
  wire [31:0] uart_wdata;
  wire [31:0] uart_rdata;
  wire uart_tx_ready;
  wire uart_tx_busy;
  wire uart_tx_valid;
  wire [7:0] uart_tx_data;

  wire spi_req;
  wire spi_we;
  wire [3:0] spi_be;
  wire [31:0] spi_addr;
  wire [31:0] spi_wdata;
  wire [31:0] spi_rdata;

  wire [31:0] imem_addr;
  wire [31:0] imem_rdata;


  simple_ram u_ram (
      .clk(clk),
      .rst_n(rst_n),
      .req(ram_req),
      .we(ram_we),
      .be(ram_be),
      .addr(ram_addr),
      .wdata(ram_wdata),
      .rdata(ram_rdata)
  );

  gpio_mmio u_gpio_mmio (
      .clk(clk),
      .rst_n(rst_n),
      .req(gpio_req),
      .we(gpio_we),
      .be(gpio_be),
      .addr(gpio_addr),
      .wdata(gpio_wdata),
      .rdata(gpio_rdata),

      .sw  (sw),
      .key (key),
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
      .gpio1_oe(gpio1_oe)
  );

  uart_tx_mmio u_uart_tx_mmio (
      .clk(clk),
      .rst_n(rst_n),
      .req(uart_req),
      .we(uart_we),
      .be(uart_be),
      .addr(uart_addr),
      .wdata(uart_wdata),
      .tx_ready(uart_tx_ready),
      .tx_busy(uart_tx_busy),
      .rdata(uart_rdata),
      .tx_valid(uart_tx_valid),
      .tx_data(uart_tx_data)
  );

  uart_tx #(
      .CLKS_PER_BIT(UART_CLKS_PER_BIT)
  ) u_uart_tx (
      .clk(clk),
      .rst_n(rst_n),
      .tx_valid(uart_tx_valid),
      .tx_data(uart_tx_data),
      .tx_ready(uart_tx_ready),
      .tx_busy(uart_tx_busy),
      .tx_pin(uart_tx_pin)
  );

  spi_master_mmio u_spi_master_mmio (
      .clk(clk),
      .rst_n(rst_n),
      .req(spi_req),
      .we(spi_we),
      .be(spi_be),
      .addr(spi_addr),
      .wdata(spi_wdata),
      .rdata(spi_rdata),
      .spi_miso(spi_miso),
      .spi_sclk(spi_sclk),
      .spi_mosi(spi_mosi),
      .spi_cs_n(spi_cs_n)
  );

  simple_rom #(
      .ROM_FILE(ROM_FILE)
  ) u_rom (
      .addr (imem_addr),
      .rdata(imem_rdata)
  );

  simple_rom #(
      .ROM_FILE(ROM_FILE)
  ) u_data_rom (
      .addr (rom_addr),
      .rdata(rom_rdata)
  );

  simple_bus u_bus (
      .clk(clk),
      .req(dmem_req),
      .we(dmem_we),
      .be(dmem_be),
      .addr(dmem_addr),
      .wdata(dmem_wdata),
      .rdata(dmem_rdata),

      .rom_req(rom_req),
      .rom_addr(rom_addr),
      .rom_rdata(rom_rdata),

      .ram_req(ram_req),
      .ram_we(ram_we),
      .ram_be(ram_be),
      .ram_addr(ram_addr),
      .ram_wdata(ram_wdata),
      .ram_rdata(ram_rdata),

      .gpio_req(gpio_req),
      .gpio_we(gpio_we),
      .gpio_be(gpio_be),
      .gpio_addr(gpio_addr),
      .gpio_wdata(gpio_wdata),
      .gpio_rdata(gpio_rdata),

      .uart_req(uart_req),
      .uart_we(uart_we),
      .uart_be(uart_be),
      .uart_addr(uart_addr),
      .uart_wdata(uart_wdata),
      .uart_rdata(uart_rdata),

      .spi_req(spi_req),
      .spi_we(spi_we),
      .spi_be(spi_be),
      .spi_addr(spi_addr),
      .spi_wdata(spi_wdata),
      .spi_rdata(spi_rdata)
  );

  rv32i_core #(
      .RESET_PC(RESET_PC)
  ) u_core (
      .clk  (clk),
      .rst_n(rst_n),

      .imem_addr (imem_addr),
      .imem_rdata(imem_rdata),

      .dmem_req(dmem_req),
      .dmem_we(dmem_we),
      .dmem_be(dmem_be),
      .dmem_addr(dmem_addr),
      .dmem_wdata(dmem_wdata),
      .dmem_rdata(dmem_rdata)
  );

endmodule
