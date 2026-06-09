`timescale 1ns / 1ps

// RV32I 整数运算单元
// 纯组合逻辑模块, 不需要等待时钟.
module alu (
    input wire [3:0] alu_op,  // 执行的计算操作
    input wire [31:0] lhs,  // 第一个运算数
    input wire [31:0] rhs,  // 第二个运算数
    output reg [31:0] result  // 计算结果
);

  // 使用 ALU 操作码在模块内部定义,
  // 后面编写 decoder 的时候, decoder 会输出这些操作码.
  localparam ALU_ADD = 4'd0;  // 加法
  localparam ALU_SUB = 4'd1;  // 减法
  localparam ALU_SLL = 4'd2;  // 左移位
  localparam ALU_SLT = 4'd3;  // 有符号比较 Less Than
  localparam ALU_SLTU = 4'd4;  // 无符号比较 Less Than Unsigned
  localparam ALU_XOR = 4'd5;  // 异或
  localparam ALU_SRL = 4'd6;  // 逻辑右移 (左边补零)
  localparam ALU_SRA = 4'd7;  // 算术右移 (保留符号位)
  localparam ALU_OR = 4'd8;  // 或
  localparam ALU_AND = 4'd9;  // 与

  always @(*) begin
    case (alu_op)
      // 加减法
      ALU_ADD: result = lhs + rhs;
      ALU_SUB: result = lhs - rhs;

      // 移位, 由于是 32 位架构, 所以移位量只取低 5 位.
      ALU_SLL: result = lhs << rhs[4:0];
      ALU_SRL: result = lhs >> rhs[4:0];

      // 算术右移, $signed: 把这个数当作有符号的数来看, >>: 逻辑右移, >>>: 算术右移.
      // $signed + >>> 组合使用才能达到左边补充符号位的效果.
      ALU_SRA: result = $signed(lhs) >>> rhs[4:0];

      // 比较
      ALU_SLT:  result = ($signed(lhs) < $signed(rhs)) ? 32'd1 : 32'd0;  // 有符号
      ALU_SLTU: result = (lhs < rhs) ? 32'd1 : 32'd0;  // 无符号

      // 逻辑运算
      ALU_XOR: result = lhs ^ rhs;
      ALU_OR:  result = lhs | rhs;
      ALU_AND: result = lhs & rhs;

      // 未知操作
      default: result = 32'b0;
    endcase
  end
endmodule
