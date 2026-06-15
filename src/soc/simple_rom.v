`timescale 1ns / 1ps

// 一个简单的 ROM 实现, 用于读取指令.
// 当前内容是上板 demo 程序:
//   1. 初始化 HEX 段码, HEX0 到 HEX5 分别显示 0 到 5.
//   2. 循环读取 SW, 并把 SW[9:0] 镜像到 LEDR[9:0].
module simple_rom #(
    parameter ROM_WORDS = 8192,
    parameter ROM_WORD_ADDR_BITS = 13,  // 8192 words = 32 KiB, 对应 0x0000_0000 - 0x0000_7fff
    parameter ROM_FILE = "firmware/board_demo/board_demo.hex"
) (
    input  wire [31:0] addr,
    output reg  [31:0] rdata
);

  reg [31:0] rom[0:ROM_WORDS-1];

  // 这个 initial 块可以被综合, Quartus 会把 hex 内容整合进 ROM.
  // 固件 hex 只需要写实际 word, 未写到的地址不要作为稳定内容依赖.
  initial begin
    $readmemh(ROM_FILE, rom);
  end

  wire [29:0] word_addr = addr[31:2];  // 字对齐

  always @(*) begin
    if (word_addr < ROM_WORDS) begin
      rdata = rom[word_addr[ROM_WORD_ADDR_BITS-1:0]];
    end else begin
      rdata = 32'h0000_0013;  // nop 指令
    end
  end

endmodule
