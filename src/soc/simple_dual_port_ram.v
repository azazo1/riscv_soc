`timescale 1ns / 1ps

// 简单双读口 RAM.
// data 口给 data bus 使用, 支持组合读和同步写.
// imem 口只读, 给 CPU 从 RAM 取指使用.
module simple_dual_port_ram #(
    parameter RAM_WORDS = 8192,
    parameter RAM_WORD_ADDR_BITS = 13
) (
    input wire clk,
    input wire rst_n,

    input wire req,
    input wire we,
    input wire [3:0] be,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output reg [31:0] rdata,

    input wire imem_req,
    input wire [31:0] imem_addr,
    output reg [31:0] imem_rdata
);

  reg [31:0] ram_data[0:RAM_WORDS-1];

  wire [RAM_WORD_ADDR_BITS-1:0] word_addr = addr[RAM_WORD_ADDR_BITS+1:2];
  wire [RAM_WORD_ADDR_BITS-1:0] imem_word_addr = imem_addr[RAM_WORD_ADDR_BITS+1:2];

  always @(*) begin
    if (req && !we) begin
      rdata = ram_data[word_addr];
    end else begin
      rdata = 32'b0;
    end
  end

  always @(*) begin
    if (imem_req) begin
      imem_rdata = ram_data[imem_word_addr];
    end else begin
      imem_rdata = 32'h0000_0013;
    end
  end

  always @(posedge clk) begin
    if (rst_n && req && we) begin
      if (be[0]) begin
        ram_data[word_addr][7:0] <= wdata[7:0];
      end
      if (be[1]) begin
        ram_data[word_addr][15:8] <= wdata[15:8];
      end
      if (be[2]) begin
        ram_data[word_addr][23:16] <= wdata[23:16];
      end
      if (be[3]) begin
        ram_data[word_addr][31:24] <= wdata[31:24];
      end
    end
  end

endmodule
