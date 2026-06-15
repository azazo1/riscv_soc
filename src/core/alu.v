`timescale 1ns / 1ps

// RV32I/RV32M 整数运算单元
// 纯组合逻辑模块, 不需要等待时钟.
module alu (
    input wire [4:0] alu_op,  // 执行的计算操作
    input wire [31:0] lhs,  // 第一个运算数
    input wire [31:0] rhs,  // 第二个运算数
    output reg [31:0] result  // 计算结果
);

  // 使用 ALU 操作码在模块内部定义,
  // 后面编写 decoder 的时候, decoder 会输出这些操作码.
  localparam ALU_ADD = 5'd0;  // 加法
  localparam ALU_SUB = 5'd1;  // 减法
  localparam ALU_SLL = 5'd2;  // 左移位
  localparam ALU_SLT = 5'd3;  // 有符号比较 Less Than
  localparam ALU_SLTU = 5'd4;  // 无符号比较 Less Than Unsigned
  localparam ALU_XOR = 5'd5;  // 异或
  localparam ALU_SRL = 5'd6;  // 逻辑右移 (左边补零)
  localparam ALU_SRA = 5'd7;  // 算术右移 (保留符号位)
  localparam ALU_OR = 5'd8;  // 或
  localparam ALU_AND = 5'd9;  // 与
  localparam ALU_MUL = 5'd10;  // 乘法低 32 bit
  localparam ALU_MULH = 5'd11;  // 有符号乘法高 32 bit
  localparam ALU_MULHSU = 5'd12;  // 有符号乘无符号高 32 bit
  localparam ALU_MULHU = 5'd13;  // 无符号乘法高 32 bit
  localparam ALU_DIV = 5'd14;  // 有符号除法
  localparam ALU_DIVU = 5'd15;  // 无符号除法
  localparam ALU_REM = 5'd16;  // 有符号取余
  localparam ALU_REMU = 5'd17;  // 无符号取余

  wire signed [63:0] lhs_s64;
  wire signed [63:0] rhs_s64;
  wire signed [63:0] rhs_u64_as_signed;
  wire [63:0] lhs_u64;
  wire [63:0] rhs_u64;
  wire signed [63:0] mul_ss;
  wire signed [63:0] mul_su;
  wire [63:0] mul_uu;

  assign lhs_s64 = {{32{lhs[31]}}, lhs};
  assign rhs_s64 = {{32{rhs[31]}}, rhs};
  assign rhs_u64_as_signed = {32'b0, rhs};
  assign lhs_u64 = {32'b0, lhs};
  assign rhs_u64 = {32'b0, rhs};
  assign mul_ss = lhs_s64 * rhs_s64;
  assign mul_su = lhs_s64 * rhs_u64_as_signed;
  assign mul_uu = lhs_u64 * rhs_u64;

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

      // RV32M 乘法.
      ALU_MUL:    result = mul_uu[31:0];
      ALU_MULH:   result = mul_ss[63:32];
      ALU_MULHSU: result = mul_su[63:32];
      ALU_MULHU:  result = mul_uu[63:32];

      // RV32M 除法和取余需要处理除以 0 和有符号溢出.
      ALU_DIV: begin
        if (rhs == 32'b0) result = 32'hffff_ffff;
        else if (lhs == 32'h8000_0000 && rhs == 32'hffff_ffff) result = 32'h8000_0000;
        else result = $signed(lhs) / $signed(rhs);
      end
      ALU_DIVU: begin
        if (rhs == 32'b0) result = 32'hffff_ffff;
        else result = lhs / rhs;
      end
      ALU_REM: begin
        if (rhs == 32'b0) result = lhs;
        else if (lhs == 32'h8000_0000 && rhs == 32'hffff_ffff) result = 32'b0;
        else result = $signed(lhs) % $signed(rhs);
      end
      ALU_REMU: begin
        if (rhs == 32'b0) result = lhs;
        else result = lhs % rhs;
      end

	      // 未知操作
	      default: result = 32'b0;
    endcase
  end
endmodule
