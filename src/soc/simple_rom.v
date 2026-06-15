`timescale 1ns / 1ps

// 一个简单的 ROM 实现, 用于读取指令
module simple_rom (
    input  wire [31:0] addr,
    output reg  [31:0] rdata
);

  always @(*) begin
    case (addr & ~(32'b1))
      32'h0000_0000: rdata = 32'h0050_0093;  // addi x1, x0, 5 ; x1 = 5
      32'h0000_0004: rdata = 32'h0070_0113;  // addi x2, x0, 7 ; x2 = 7
      32'h0000_0008: rdata = 32'h0020_81b3;  // add x3, x1, x2 ; x3 = x1 + x2 = 12
      32'h0000_000c: rdata = 32'h0030_2023;  // sw x3, 0(x0) ; 把 12 写入 RAM 地址 0
      32'h0000_0010: rdata = 32'h0000_2203;  // lw x4, 0(x0) ; 从 RAM 地址 0 读回到 x4
      32'h0000_0014: rdata = 32'h0041_8463;  // beq x3, x4, +8 ; 如果读写正确, 跳过失败
      32'h0000_0018: rdata = 32'h0010_0293;  // add x5, x0, 1 ; 失败标记
      32'h0000_001c: rdata = 32'h0020_0293;  // addi x1, x0, 2 ; 成功标记
      32'h0000_0020: rdata = 32'h0000_0063;  // beq x0, x0, 0 ; 原地死循环, 停住
      default: rdata = 32'h0000_0013;
    endcase
  end

endmodule
