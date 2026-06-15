`timescale 1ns / 1ps

// 简单 UART TX
// 空闲时 tx_pin 输出 1, 发送时依次输出 start bit, 8 个 data bit, stop bit.
module uart_tx #(
    // CLKS_PER_BIT = clk_hz / baud, example: 50 MHz / 115200 ~= 434.
    parameter CLKS_PER_BIT = 434
) (
    input wire clk,
    input wire rst_n,
    input wire tx_valid,        // 发送命令, 高电平有效, 将被转换为一个周期的发送脉冲
    input wire [7:0] tx_data,  // 待发送的字节数据
    output wire tx_ready,  // 模块空闲标志, 为 1 时表示可接受新字节
    output wire tx_busy,  // 模块忙碌标志, 为 1 时表示正在发送
    output wire tx_pin  // UART TX 串行输出引脚
);

  localparam STATE_IDLE  = 2'd0;  // 空闲, 等待 tx_valid
  localparam STATE_START = 2'd1;  // 发送 start bit (拉低)
  localparam STATE_DATA  = 2'd2;  // 逐 bit 发送 8 位数据, LSB 优先
  localparam STATE_STOP  = 2'd3;  // 发送 stop bit (拉高), 完成后回到 IDLE

  reg [1:0] state;
  reg [31:0] clk_count;  // 波特率分频计数器
  reg [2:0] bit_index;   // 当前发送的 bit 序号 (0-7)
  reg [7:0] data_reg;    // tx_valid 时锁存的待发送字节
  reg tx_reg;            // tx_pin 输出寄存器

  assign tx_ready = (state == STATE_IDLE);
  assign tx_busy  = (state != STATE_IDLE);
  assign tx_pin   = tx_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      clk_count <= 32'b0;
      bit_index <= 3'b0;
      data_reg <= 8'b0;
      tx_reg <= 1'b1;
    end else begin
      case (state)
        STATE_IDLE: begin
          // 空闲阶段保持 TX 为高电平, 等待上层送来一个字节.
          tx_reg <= 1'b1;
          clk_count <= 32'b0;
          bit_index <= 3'b0;
          if (tx_valid) begin
            // 接收到发送请求后锁存数据, 先拉低 TX 进入 start bit.
            data_reg <= tx_data;
            tx_reg <= 1'b0;
            state <= STATE_START;
          end
        end

        STATE_START: begin
          if (clk_count == CLKS_PER_BIT - 1) begin  // 分频
            // start bit 保持满一个 bit 时间后, 开始发送 bit 0.
            clk_count <= 32'b0;
            bit_index <= 3'b0;
            tx_reg <= data_reg[0];
            state <= STATE_DATA;
          end else begin
            clk_count <= clk_count + 1;
          end
        end

        STATE_DATA: begin
          if (clk_count == CLKS_PER_BIT - 1) begin
            // 每过一个 bit 时间, 切换到下一个数据位.
            clk_count <= 32'b0;
            if (bit_index == 3'd7) begin
              // bit 7 发送完成后, 拉高 TX 进入 stop bit.
              tx_reg <= 1'b1;
              state  <= STATE_STOP;
            end else begin
              bit_index <= bit_index + 3'd1;
              tx_reg <= data_reg[bit_index+3'd1];
            end
          end else begin
            clk_count <= clk_count + 1;
          end
        end

        STATE_STOP: begin
          if (clk_count == CLKS_PER_BIT - 1) begin
            // stop bit 发送完成后回到空闲, 下一拍 tx_ready 重新有效.
            clk_count <= 32'b0;
            tx_reg <= 1'b1;
            state <= STATE_IDLE;
          end else begin
            clk_count <= clk_count + 1;
          end
        end

        default: begin
          // 异常状态保护, 回到空闲并保持 TX 为高电平.
          state  <= STATE_IDLE;
          tx_reg <= 1'b1;
        end
      endcase
    end
  end

endmodule
