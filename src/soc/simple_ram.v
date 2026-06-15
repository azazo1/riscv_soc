`timescale 1ns / 1ps

// 简单的 RAM, 用于存储数据
module simple_ram (
    input wire clk,
    input wire req,
    input wire we,
    input wire [3:0] be,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output reg [31:0] rdata
);

  reg [31:0] ram_data[0:255];
  wire [7:0] word_addr = addr[9:2];

  // 读取 组合逻辑 (异步)
  always @(*) begin
    if (req && !we) begin
      rdata = ram_data[addr>>2];
    end else begin
      rdata = 32'b0;
    end
  end

  // 写入 时序逻辑 (同步)
  always @(posedge clk) begin
    if (req && we) begin
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
