`timescale 1ns / 1ps

// 简单 UART TX
// 空闲时 uart_tx 输出 1, 发送时依次输出 start bit, 8 个 data bit, stop bit.
module uart_tx #(
    // CLKS_PER_BIT = clk_hz / baud, example: 50 MHz / 115200 ~= 434.
    parameter CLKS_PER_BIT = 434
) (
    input wire clk,
    input wire rst_n,
    input wire tx_valid,
    input wire [7:0] tx_data,
    output wire tx_ready,
    output wire tx_busy,
    output wire uart_tx
);

  localparam STATE_IDLE = 2'd0;
  localparam STATE_START = 2'd1;
  localparam STATE_DATA = 2'd2;
  localparam STATE_STOP = 2'd3;

  reg [1:0] state;
  reg [31:0] clk_count;
  reg [2:0] bit_index;
  reg [7:0] data_reg;
  reg tx_reg;

  assign tx_ready = (state == STATE_IDLE);
  assign tx_busy  = (state != STATE_IDLE);
  assign uart_tx  = tx_reg;

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
          tx_reg <= 1'b1;
          clk_count <= 32'b0;
          bit_index <= 3'b0;
          if (tx_valid) begin
            data_reg <= tx_data;
            tx_reg <= 1'b0;
            state <= STATE_START;
          end
        end

        STATE_START: begin
          if (clk_count == CLKS_PER_BIT - 1) begin  // 分频
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
            clk_count <= 32'b0;
            if (bit_index == 3'd7) begin
              tx_reg <= 1'b1;
              state  <= STATE_STOP;
            end else begin
              bit_index <= bit_index + 1;
              tx_reg <= data_reg[bit_index+1];
            end
          end else begin
            clk_count <= clk_count + 1;
          end
        end

        STATE_STOP: begin
          if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 32'b0;
            tx_reg <= 1'b1;
            state <= STATE_IDLE;
          end else begin
            clk_count <= clk_count + 1;
          end
        end

        default: begin
          state  <= STATE_IDLE;
          tx_reg <= 1'b1;
        end
      endcase
    end
  end

endmodule
