`timescale 1ns / 1ps

// 分支单元, 判断跳转是否生效.
module branch_unit (
    input wire [2:0] funct3,
    input wire [31:0] lhs, // 分支比较左操作数, 通常来自 rs1_data
    input wire [31:0] rhs, // 分支比较右操作数, 通常来自 rs2_data
    output reg branch_taken // 分支单元的判断结果输出信号, 如果为 1, 那么分支条件满足, 可以跳转.
);
  localparam BR_BEQ = 3'b000;
  localparam BR_BNE = 3'b001;
  localparam BR_BLT = 3'b100;
  localparam BR_BGE = 3'b101;
  localparam BR_BLTU = 3'b110;
  localparam BR_BGEU = 3'b111;

  always @(*) begin
    case (funct3)
      BR_BEQ:  branch_taken = (lhs == rhs);
      BR_BNE:  branch_taken = (lhs != rhs);
      // 两个都必须标记 $signed, 否则就会无符号传染.
      BR_BLT:  branch_taken = ($signed(lhs) < $signed(rhs));
      BR_BGE:  branch_taken = ($signed(lhs) >= $signed(rhs));
      BR_BLTU: branch_taken = (lhs < rhs);
      BR_BGEU: branch_taken = (lhs >= rhs);
      default: branch_taken = 1'b0;
    endcase
  end

endmodule
