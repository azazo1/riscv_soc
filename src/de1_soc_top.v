`timescale 1ns / 1ps

// 适用于 de1_soc 的顶层模块, 用于在 quartus 中直接编译.
module de1_soc_top (
    input wire clk,

    input  wire [9:0] sw,
    input  wire [3:0] key,
    output wire [9:0] ledr,
    output wire [6:0] hex0,
    output wire [6:0] hex1,
    output wire [6:0] hex2,
    output wire [6:0] hex3,
    output wire [6:0] hex4,
    output wire [6:0] hex5,
    output wire [6:0] hex6,
    output wire [6:0] hex7
);

  rv32i_soc u_soc (
      .clk(clk),
      .rst_n(key[0]),  // 暂时将 KEY0 作为 rst_n.
      .sw(sw),
      .key(key),
      .ledr(ledr),
      .hex0(hex0),
      .hex1(hex1),
      .hex2(hex2),
      .hex3(hex3),
      .hex4(hex4),
      .hex5(hex5),
      .hex6(hex6),
      .hex7(hex7)
  );

endmodule
