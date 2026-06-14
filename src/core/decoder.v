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
    output wire is_lui,  // load upper immediate, 处理"比较大的立即数"
    output wire is_auipc,  // add upper immediate to pc, rd = pc + imm_u
    output wire is_jal,
    output wire is_jalr,
    output wire is_branch,
    output wire is_load,
    output wire is_store,
    output wire is_op_imm,
    output wire is_op,

    output wire rd_we,  // 是否写回寄存器 rd
    output wire alu_src_imm,  // ALU 右操作数是否来自 immediate
    output wire mem_read,  // 是否读数据内存
    output wire mem_write,  // 是否写数据内存
    output wire branch,  // 是否是条件分支
    output wire jump,  // 是否是 `jal` 或者 `jalr`

    output reg [3:0] alu_op  // ALU 操作识别
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

  // 查看 alu.v 获取这些值的意义
  localparam ALU_ADD = 4'd0;
  localparam ALU_SUB = 4'd1;
  localparam ALU_SLL = 4'd2;
  localparam ALU_SLT = 4'd3;
  localparam ALU_SLTU = 4'd4;
  localparam ALU_XOR = 4'd5;
  localparam ALU_SRL = 4'd6;
  localparam ALU_SRA = 4'd7;
  localparam ALU_OR = 4'd8;
  localparam ALU_AND = 4'd9;

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

  assign rd_we = is_lui || is_auipc || is_jal || is_jalr || is_load || is_op_imm || is_op;
  assign alu_src_imm = is_lui || is_auipc || is_jalr || is_load || is_store || is_op_imm;
  assign mem_read = is_load;
  assign mem_write = is_store;

  assign branch = is_branch;
  assign jump = is_jal || is_jalr;

  always @(*) begin
    case (funct3)
      3'b000: begin
        if (is_op && funct7 == 7'b0100000)
          alu_op = ALU_SUB;  // 加上 is_op 的判断防止是立即数导致的, 立即数操作没有 SUBI.
        else alu_op = ALU_ADD;
      end
      3'b001: alu_op = ALU_SLL;
      3'b010: alu_op = ALU_SLT;
      3'b011: alu_op = ALU_SLTU;
      3'b100: alu_op = ALU_XOR;
      3'b101: begin
        if (funct7 == 7'b0100000) alu_op = ALU_SRA;
        else alu_op = ALU_SRL;
      end
      3'b110: alu_op = ALU_OR;
      3'b111: alu_op = ALU_AND;
      default:
      alu_op = ALU_ADD;  // todo 现在暂时不添加无效指令的分辨, 后续再添加.
    endcase
  end

endmodule
