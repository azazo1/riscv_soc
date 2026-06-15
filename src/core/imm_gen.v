`timescale 1ns / 1ps

// 立即数生成器
module imm_gen (
    input wire [31:0] instr,
    input wire [ 2:0] imm_sel,

    output wire [31:0] imm_i,
    output wire [31:0] imm_s,
    output wire [31:0] imm_b,
    output wire [31:0] imm_u,  // Upper, lui / auipc, 加载大立即数的高 20 位
    output wire [31:0] imm_j,
    // R-type 指令没有立即数
    output reg [31:0] imm  // 似乎编写了 reg 仍有可能被综合成 wire.
);


  // I-type: instr[31:20] 需要符号拓展到 32 位
  assign imm_i = {{20{instr[31]}}, instr[31:20]};
  // S-type: 
  assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
  // B-type:
  assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
  // U-type:
  assign imm_u = {instr[31:12], 12'b0};
  // J-type:
  assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

  // 不同类型的指令立即数
  localparam IMM_I = 3'd0;
  localparam IMM_S = 3'd1;
  localparam IMM_B = 3'd2;
  localparam IMM_U = 3'd3;
  localparam IMM_J = 3'd4;

  always @(*) begin
    case (imm_sel)
      IMM_I:   imm = imm_i;
      IMM_S:   imm = imm_s;
      IMM_B:   imm = imm_b;
      IMM_U:   imm = imm_u;
      IMM_J:   imm = imm_j;
      // 可能需要解决非法指令的问题, 但是 imm_sel 实际上是由 decoder 产生的,
      // 而不是提取出来的, 如果接线正常, 是不会有无效值的.
      default: imm = 32'b0;
    endcase
  end

endmodule
