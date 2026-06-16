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
    output wire spi_cs_n,

    // vga output.
    output wire [7:0] vga_r,
    output wire [7:0] vga_g,
    output wire [7:0] vga_b,
    output wire vga_hs,
    output wire vga_vs,
    output wire vga_blank_n,
    output wire vga_sync_n,
    output wire vga_clk,

    // de1-soc onboard sdram.
    output wire [12:0] sdram_addr,
    output wire [1:0] sdram_ba,
    output wire sdram_cas_n,
    output wire sdram_cke,
    output wire sdram_clk,
    output wire sdram_cs_n,
    inout wire [15:0] sdram_dq,
    output wire sdram_ldqm,
    output wire sdram_ras_n,
    output wire sdram_udqm,
    output wire sdram_we_n
);

  wire dmem_req;
  wire dmem_we;
  wire [3:0] dmem_be;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  wire [31:0] dmem_rdata;
  wire dmem_ready;

  wire ram_req;
  wire ram_we;
  wire [3:0] ram_be;
  wire [31:0] ram_addr;
  wire [31:0] ram_wdata;
  wire [31:0] ram_rdata;
  wire ram_ready;

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

  wire sdram_req;
  wire sdram_we;
  wire [3:0] sdram_be;
  wire [31:0] sdram_bus_addr;
  wire [31:0] sdram_wdata;
  wire [31:0] sdram_rdata;
  wire sdram_ready;
  wire [1:0] sdram_dqm;
  wire vga_sdram_req;
  wire [31:0] vga_sdram_addr;
  wire [31:0] vga_sdram_rdata;
  wire vga_sdram_ready;
  wire mem_sdram_req;
  wire mem_sdram_we;
  wire [3:0] mem_sdram_be;
  wire [31:0] mem_sdram_addr;
  wire [31:0] mem_sdram_wdata;
  wire [31:0] mem_sdram_rdata;
  wire mem_sdram_ready;

  wire [31:0] imem_addr;
  wire [31:0] imem_rdata;
  wire imem_ready;
  wire [31:0] rom_imem_rdata;
  wire [31:0] ram_imem_addr;
  wire [31:0] ram_imem_rdata;
  wire ram_imem_ready;
  wire imem_sdram_req;
  wire [31:0] imem_sdram_addr;
  wire [31:0] imem_sdram_rdata;
  wire imem_sdram_ready;

  localparam ROM_LIMIT = 32'h0000_8000;
  localparam RAM_BASE = 32'h0000_f000;
  localparam RAM_LIMIT = 32'h0001_0000;
  localparam SDRAM_BASE = 32'h0200_0000;
  localparam SDRAM_LIMIT = 32'h0600_0000;

  wire imem_rom_hit = imem_addr < ROM_LIMIT;
  wire imem_ram_hit = (imem_addr >= RAM_BASE) && (imem_addr < RAM_LIMIT);
  wire imem_sdram_hit = (imem_addr >= SDRAM_BASE) && (imem_addr < SDRAM_LIMIT);
  wire imem_sdram_cache_hit;
  wire imem_sdram_access_ready;

  reg imem_sdram_busy;
  reg imem_sdram_valid;
  reg [31:0] imem_sdram_cpu_addr_q;
  reg [31:0] imem_sdram_req_addr_q;
  reg [31:0] imem_sdram_cache_addr_q;
  reg [31:0] imem_sdram_cache_data_q;

  assign ram_imem_addr = imem_addr - RAM_BASE;
  assign imem_sdram_addr = imem_sdram_req_addr_q;
  assign imem_sdram_req = imem_sdram_busy;
  assign imem_sdram_cache_hit = imem_sdram_valid && imem_sdram_cache_addr_q == imem_addr;
  assign imem_sdram_access_ready = imem_sdram_cache_hit || (imem_sdram_busy && imem_sdram_ready);
  assign imem_rdata = imem_rom_hit ? rom_imem_rdata :
                      imem_ram_hit ? ram_imem_rdata :
                      imem_sdram_hit ?
                      (imem_sdram_cache_hit ? imem_sdram_cache_data_q : imem_sdram_rdata) :
                      32'h0000_0013;
  assign imem_ready = imem_rom_hit ? 1'b1 :
                      imem_ram_hit ? ram_imem_ready :
                      imem_sdram_hit ? imem_sdram_access_ready : 1'b1;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      imem_sdram_busy <= 1'b0;
      imem_sdram_valid <= 1'b0;
      imem_sdram_cpu_addr_q <= 32'b0;
      imem_sdram_req_addr_q <= 32'b0;
      imem_sdram_cache_addr_q <= 32'b0;
      imem_sdram_cache_data_q <= 32'h0000_0013;
    end else if (imem_sdram_busy) begin
      if (imem_sdram_ready) begin
        imem_sdram_busy <= 1'b0;
        imem_sdram_valid <= 1'b1;
        imem_sdram_cache_addr_q <= imem_sdram_cpu_addr_q;
        imem_sdram_cache_data_q <= imem_sdram_rdata;
      end
    end else if (imem_sdram_hit && !imem_sdram_cache_hit) begin
      imem_sdram_busy <= 1'b1;
      imem_sdram_cpu_addr_q <= imem_addr;
      imem_sdram_req_addr_q <= imem_addr - SDRAM_BASE;
    end
  end

  onchip_dual_port_ram #(
      .RAM_WORD_ADDR_BITS(10)
  ) u_ram (
      .clk(clk),
      .rst_n(rst_n),
      .req(ram_req),
      .we(ram_we),
      .be(ram_be),
      .addr(ram_addr),
      .wdata(ram_wdata),
      .rdata(ram_rdata),
      .ready(ram_ready),
      .imem_req(imem_ram_hit),
      .imem_addr(ram_imem_addr),
      .imem_rdata(ram_imem_rdata),
      .imem_ready(ram_imem_ready)
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

  assign sdram_ldqm = sdram_dqm[0];
  assign sdram_udqm = sdram_dqm[1];

  vga_sdram_fb u_vga_sdram_fb (
      .clk(clk),
      .rst_n(rst_n),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .vga_hs(vga_hs),
      .vga_vs(vga_vs),
      .vga_blank_n(vga_blank_n),
      .vga_sync_n(vga_sync_n),
      .vga_clk(vga_clk),
      .sdram_req(vga_sdram_req),
      .sdram_addr(vga_sdram_addr),
      .sdram_rdata(vga_sdram_rdata),
      .sdram_ready(vga_sdram_ready)
  );

  sdram_arbiter u_sdram_arbiter (
      .clk(clk),
      .rst_n(rst_n),
      .cpu_req(sdram_req),
      .cpu_we(sdram_we),
      .cpu_be(sdram_be),
      .cpu_addr(sdram_bus_addr),
      .cpu_wdata(sdram_wdata),
      .cpu_rdata(sdram_rdata),
      .cpu_ready(sdram_ready),
      .imem_req(imem_sdram_req),
      .imem_addr(imem_sdram_addr),
      .imem_rdata(imem_sdram_rdata),
      .imem_ready(imem_sdram_ready),
      .vga_req(vga_sdram_req),
      .vga_addr(vga_sdram_addr),
      .vga_rdata(vga_sdram_rdata),
      .vga_ready(vga_sdram_ready),
      .mem_req(mem_sdram_req),
      .mem_we(mem_sdram_we),
      .mem_be(mem_sdram_be),
      .mem_addr(mem_sdram_addr),
      .mem_wdata(mem_sdram_wdata),
      .mem_rdata(mem_sdram_rdata),
      .mem_ready(mem_sdram_ready)
  );

  sdram_ctrl_wrapper u_sdram_ctrl_wrapper (
      .clk(clk),
      .rst_n(rst_n),
      .req(mem_sdram_req),
      .we(mem_sdram_we),
      .be(mem_sdram_be),
      .addr(mem_sdram_addr),
      .wdata(mem_sdram_wdata),
      .rdata(mem_sdram_rdata),
      .ready(mem_sdram_ready),
      .init_done(),
      .sdram_clk(sdram_clk),
      .sdram_addr(sdram_addr),
      .sdram_ba(sdram_ba),
      .sdram_cs_n(sdram_cs_n),
      .sdram_cke(sdram_cke),
      .sdram_ras_n(sdram_ras_n),
      .sdram_cas_n(sdram_cas_n),
      .sdram_we_n(sdram_we_n),
      .sdram_dqm(sdram_dqm),
      .sdram_dq(sdram_dq)
  );

  simple_rom #(
      .ROM_FILE(ROM_FILE)
  ) u_rom (
      .addr (imem_addr),
      .rdata(rom_imem_rdata)
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
      .ready(dmem_ready),

      .rom_req(rom_req),
      .rom_addr(rom_addr),
      .rom_rdata(rom_rdata),

      .ram_req(ram_req),
      .ram_we(ram_we),
      .ram_be(ram_be),
      .ram_addr(ram_addr),
      .ram_wdata(ram_wdata),
      .ram_rdata(ram_rdata),
      .ram_ready(ram_ready),

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
      .spi_rdata(spi_rdata),

      .sdram_req(sdram_req),
      .sdram_we(sdram_we),
      .sdram_be(sdram_be),
      .sdram_addr(sdram_bus_addr),
      .sdram_wdata(sdram_wdata),
      .sdram_rdata(sdram_rdata),
      .sdram_ready(sdram_ready)
  );

  rv32i_core #(
      .RESET_PC(RESET_PC)
  ) u_core (
      .clk  (clk),
      .rst_n(rst_n),

      .imem_addr (imem_addr),
      .imem_rdata(imem_rdata),
      .imem_ready(imem_ready),

      .dmem_req(dmem_req),
      .dmem_we(dmem_we),
      .dmem_be(dmem_be),
      .dmem_addr(dmem_addr),
      .dmem_wdata(dmem_wdata),
      .dmem_rdata(dmem_rdata),
      .dmem_ready(dmem_ready)
  );

endmodule
