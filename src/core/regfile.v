`timescale 1ns / 1ps
// 寄存器堆, 用于根据地址读取寄存器的值
module regfile (
    input wire clk,
    input wire rst_n,

    // 在 rv32i 指令集架构中, 有 32 个寄存器, 使用五位的地址即可完成寻址寄存器.
    input wire [4:0] rs1_addr,  // 源寄存器 1
    input wire [4:0] rs2_addr,  // 源寄存器 2

    output wire [31:0] rs1_data,  // 寄存器 1 输出值
    output wire [31:0] rs2_data,  // 寄存器 2 输出值

    input wire rd_we,  // 目标寄存器是否写入 (destination register write enable)
    input wire [4:0] rd_addr,  // 目标寄存器地址
    input wire [31:0] rd_data  // 目标寄存器写入数据
);

  reg [31:0] regs[0:31];

  assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 : regs[rs1_addr];
  assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 : regs[rs2_addr];

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 32; ++i) begin
        regs[i] <= 32'b0;
      end
    end else begin
      if (rd_we && rd_addr != 5'b0) begin
        regs[rd_addr] <= rd_data;
      end
    end
  end
endmodule
