`timescale 1ns / 1ps

// 计算 next_pc 的组合逻辑电路 (给 pc_reg 用)
// next_pc = pc+4 (默认), 或 pc+imm (分支/JAL), 或 (rs1_data+imm)&~1 (JALR)
module next_pc_unit (
    input wire [31:0] pc,            // 当前 PC 值
    input wire [31:0] imm,           // 立即数偏移量
    input wire [31:0] rs1_data,      // rs1 读出数据 (JALR 基址)
    input wire        branch,        // 当前指令是否为分支指令
    input wire        branch_taken,  // 分支条件是否满足 (来自 branch_unit)
    input wire        jump,          // 当前是否是 jump 指令
    input wire        is_jalr,       // 区分 JAL 和 JALR

    output reg [31:0] next_pc  // 下一条指令的 PC 地址
);
  always @(*) begin
    next_pc = pc + 4;
    // 注意这里的优先级, Jump 需要优先于 Branch.
    if (jump && is_jalr) begin  // Jump And Link Register, 使用 rs1 + imm 跳转.
      // risc-v 规定, JALR 结果最低位需要置 0.
      next_pc = (rs1_data + imm) & ~(32'h1);
    end else if (jump && !is_jalr) begin  // Jump And Link, 使用 pc + imm 跳转.
      // 这里不需要置最低位为 0, 因为可以看 imm_gen.v 里面就规定了 imm 在 J-type 指令是最低位必定为 0.
      // 所以其实 JAL 也是要结果最低位为 0.
      next_pc = pc + imm;  // 下面不置零的都是同理.
    end else if (branch && branch_taken) begin
      next_pc = pc + imm;
    end
  end
endmodule
