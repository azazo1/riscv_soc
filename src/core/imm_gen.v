`timescale 1ns / 1ps

// 立即数生成器
module imm_gen (
    input  wire [31:0] instr,
    output wire [31:0] imm_i,
    output wire [31:0] imm_s,
    output wire [31:0] imm_b,
    output wire [31:0] imm_u,
    output wire [31:0] imm_j
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
endmodule
