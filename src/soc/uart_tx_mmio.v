`timescale 1ns / 1ps

// UART TX 的 MMIO 寄存器
// 0x0100_0100 UART_TXDATA, 写低 8 bit 后发送一个字节
// 0x0100_0104 UART_STATUS, bit0=tx_ready, bit1=tx_busy
module uart_tx_mmio (
    input wire clk,
    input wire rst_n,
    input wire req,
    input wire we,
    input wire [3:0] be,
    input wire [31:0] addr,
    input wire [31:0] wdata,

    input wire tx_ready,
    input wire tx_busy,

    output reg [31:0] rdata,
    output reg tx_valid,
    output reg [7:0] tx_data
);

  localparam ADDR_TXDATA = 6'h00;  // 0x0100_0100
  localparam ADDR_STATUS = 6'h01;  // 0x0100_0104

  wire addr_hit = (addr[31:8] == 24'h010001);
  wire [5:0] addr_offset = addr[7:2];

  always @(*) begin
    if (req && !we && addr_hit) begin
      case (addr_offset)
        ADDR_TXDATA: rdata = {24'b0, tx_data};
        ADDR_STATUS: rdata = {30'b0, tx_busy, tx_ready};
        default: rdata = 32'b0;
      endcase
    end else begin
      rdata = 32'b0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_valid <= 1'b0;
      tx_data <= 8'b0;
    end else begin
      tx_valid <= 1'b0;

      if (req && we && addr_hit && addr_offset == ADDR_TXDATA && be[0] && tx_ready) begin
        tx_data <= wdata[7:0];
        tx_valid <= 1'b1;
      end
    end
  end

endmodule
