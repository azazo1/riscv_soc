`timescale 1ns / 1ps

// 一个简单的 ROM 实现, 用于读取指令.
// 当前内容是上板 demo 程序:
//   1. 初始化 HEX 段码, HEX0 到 HEX5 分别显示 0 到 5.
//   2. 循环读取 SW, 并把 SW[9:0] 镜像到 LEDR[9:0].
module simple_rom (
    input  wire [31:0] addr,
    output reg  [31:0] rdata
);

  always @(*) begin
    case (addr & ~(32'b11))
      32'h0000_0000: rdata = 32'h0100_00b7;  // lui x1, 0x01000, x1 = 0x0100_0000
      32'h0000_0004: rdata = 32'h3024_8137;  // lui x2, 0x30248
      32'h0000_0008: rdata = 32'h9401_0113;  // addi x2, x2, 0x940, x2 = 0x3024_7940
      32'h0000_000c: rdata = 32'h0020_a623;  // sw x2, 12(x1), 写 HEX0 到 HEX3
      32'h0000_0010: rdata = 32'h0000_11b7;  // lui x3, 0x00001
      32'h0000_0014: rdata = 32'h2191_8193;  // addi x3, x3, 0x219, x3 = 0x0000_1219
      32'h0000_0018: rdata = 32'h0030_a823;  // sw x3, 16(x1), 写 HEX4 到 HEX5
      32'h0000_001c: rdata = 32'h0040_a203;  // lw x4, 4(x1), 读取 SW
      32'h0000_0020: rdata = 32'h0040_a023;  // sw x4, 0(x1), 写 LEDR
      32'h0000_0024: rdata = 32'hfe00_0ce3;  // beq x0, x0, -8, 回到读取 SW
      default: rdata = 32'h0000_0013;  // nop
    endcase
  end

endmodule
