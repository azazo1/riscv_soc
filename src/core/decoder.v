`timescale 1ns / 1ps

// 指令译码器
module decoder (
    input wire [31:0] instr,
    output wire [6:0] opcode,
    output wire [4:0] rd,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output wire is_lui,
    output wire is_auipc,
    output wire is_jal,
    output wire is_jalr,
    output wire is_branch,
    output wire is_load,
    output wire is_store,
    output wire is_op_imm,
    output wire is_op
);

  localparam OPCODE_LUI = 7'b0110111;
  localparam OPCODE_AUIPC = 7'b0010111;
  localparam OPCODE_JAL = 7'b1101111;
  localparam OPCODE_JALR = 7'b1100111;
  localparam OPCODE_BRANCH = 7'b1100011;
  localparam OPCODE_LOAD = 7'b0000011;
  localparam OPCODE_STORE = 7'b0100011;
  localparam OPCODE_OP_IMM = 7'b0010011;
  localparam OPCODE_OP = 7'b0110011;

  assign opcode = instr[6:0];
  assign rd = instr[11:7];
  assign funct3 = instr[14:12];
  assign rs1 = instr[19:15];
  assign rs2 = instr[24:20];
  assign funct7 = instr[31:25];

  assign is_lui = opcode == OPCODE_LUI;
  assign is_auipc = opcode == OPCODE_AUIPC;
  assign is_jal = opcode == OPCODE_JAL;
  assign is_jalr = opcode == OPCODE_JALR;
  assign is_branch = opcode == OPCODE_BRANCH;
  assign is_load = opcode == OPCODE_LOAD;
  assign is_store = opcode == OPCODE_STORE;
  assign is_op_imm = opcode == OPCODE_OP_IMM;
  assign is_op = opcode == OPCODE_OP;

endmodule
