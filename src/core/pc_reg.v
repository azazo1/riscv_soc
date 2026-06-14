`timescale 1ns / 1ps

// PC 计数器寄存器
module pc_reg #(
    parameter RESET_PC = 32'h0000_0000
) (
    input wire clk,
    input wire rst_n,
    input wire [31:0] next_pc,
    output reg [31:0] pc
);

  // 阻塞赋值 vs 非阻塞赋值:
  //   =  (阻塞赋值)   用于组合逻辑, 语句顺序执行, 立即生效, 适合 always @(*) 块
  //   <= (非阻塞赋值) 用于时序逻辑, 所有右值在块入口同时采样, 所有左值在块出口同时更新,
  //                    避免同一时钟沿下不同信号因赋值顺序不同而产生仿真差异, 匹配触发器行为
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= RESET_PC;
    end else begin
      pc <= next_pc;
    end
  end
endmodule
