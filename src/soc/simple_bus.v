`timescale 1ns / 1ps

// 简单的总线, 用于 RAM 和 MMIO
module simple_bus (
    input wire clk, // clk 暂时没有, 但是后面接入 SDRAM, 外设访问, 总线仲裁的时候有用.

    // core 输入的读写请求
    input wire req,
    input wire we,
    input wire [3:0] be,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output reg [31:0] rdata,

    // 转发读请求到 rom
    output wire rom_req,
    output wire [31:0] rom_addr,
    input wire [31:0] rom_rdata,

    // 转发请求到 ram
    output wire ram_req,
    output wire ram_we,
    output wire [3:0] ram_be,
    output wire [31:0] ram_addr,
    output wire [31:0] ram_wdata,
    input wire [31:0] ram_rdata,

    // 转发请求到 gpio
    output wire gpio_req,
    output wire gpio_we,
    output wire [3:0] gpio_be,
    output wire [31:0] gpio_addr,
    output wire [31:0] gpio_wdata,
    input wire [31:0] gpio_rdata,

    // 转发请求到 uart
    output wire uart_req,
    output wire uart_we,
    output wire [3:0] uart_be,
    output wire [31:0] uart_addr,
    output wire [31:0] uart_wdata,
    input wire [31:0] uart_rdata,

    // 转发请求到 spi
    output wire spi_req,
    output wire spi_we,
    output wire [3:0] spi_be,
    output wire [31:0] spi_addr,
    output wire [31:0] spi_wdata,
    input wire [31:0] spi_rdata
);

  localparam RAM_BASE = 32'h0000_8000;
  localparam RAM_LIMIT = 32'h0100_0000;
  localparam ROM_LIMIT = 32'h0000_8000;

  // 暂时定一个简单的 memory map
  // 0x0000_0000 - 0x0000_7fff IMEM, 取指直连 ROM, data bus 可只读访问常量
  // 0x0000_8000 - 0x00ff_ffff RAM, bus 转成本地地址后访问 simple_ram
  // 0x0100_0000 - 0x0100_00ff MMIO-GPIO, 内部具体映射查看 gpio_mmio.v
  // 0x0100_0100 - 0x0100_01ff MMIO-UART, 内部具体映射查看 uart_tx_mmio.v
  // 0x0100_0200 - 0x0100_02ff MMIO-SPI, 内部具体映射查看 spi_master_mmio.v

  wire rom_hit = (addr < ROM_LIMIT);
  wire ram_hit = (addr >= RAM_BASE) && (addr < RAM_LIMIT);

  assign rom_req = req && !we && rom_hit;
  assign rom_addr = addr;

  assign ram_req = req && ram_hit;
  assign ram_we = we;
  assign ram_be = be;
  assign ram_addr = addr - RAM_BASE;
  assign ram_wdata = wdata;

  assign gpio_req = req && (addr[31:8] == 24'h010000);
  assign gpio_we = we;
  assign gpio_be = be;
  assign gpio_addr = addr;
  assign gpio_wdata = wdata;

  assign uart_req = req && (addr[31:8] == 24'h010001);
  assign uart_we = we;
  assign uart_be = be;
  assign uart_addr = addr;
  assign uart_wdata = wdata;

  assign spi_req = req && (addr[31:8] == 24'h010002);
  assign spi_we = we;
  assign spi_be = be;
  assign spi_addr = addr;
  assign spi_wdata = wdata;

  always @(*) begin
    if (rom_req) begin
      rdata = rom_rdata;
    end else if (ram_req) begin  // 不能只看 ram_hit 而不看 req, 因为 req 为 0 的时候总线应该为空闲.
      rdata = ram_rdata;
    end else if (gpio_req) begin
      rdata = gpio_rdata;
    end else if (uart_req) begin
      rdata = uart_rdata;
    end else if (spi_req) begin
      rdata = spi_rdata;
    end else rdata = 32'b0;
  end

endmodule
