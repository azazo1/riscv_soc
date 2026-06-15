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

    // 转发请求到 ram
    output wire ram_req,
    output wire ram_we,
    output wire [3:0] ram_be,
    output wire [31:0] ram_addr,
    output wire [31:0] ram_wdata,
    input wire [31:0] ram_rdata
);

  // 暂时定一个简单的 memory map
  // 0x0000_0000 - 0x00ff_ffff RAM // 但是暂时 RAM 容量只有 256 * 4 = 1024 字节
  // 0x1000_0000 - 0x1000_00ff MMIO

  wire ram_hit;

  assign ram_hit = addr[31:24] == 8'b0;
  assign ram_req = req && ram_hit;
  assign ram_we = we;
  assign ram_be = be;
  assign ram_addr = addr;
  assign ram_wdata = wdata;

  always @(*) begin
    if (ram_req) begin  // 不能只看 ram_hit, 因为 req 为 0 的时候总线应该为空闲.
      rdata = ram_rdata;
    end else begin  // todo MMIO
      rdata = 32'b0;
    end
  end

endmodule
