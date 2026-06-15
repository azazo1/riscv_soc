`timescale 1ns / 1ps

// VGA 640x480@60Hz 时序发生器.
module vga_timing (
    input wire clk,
    input wire clk_en,
    input wire rst_n,

    output reg [9:0] x,
    output reg [9:0] y,
    output wire visible,
    output wire hsync,
    output wire vsync
);

  // 640x480@60Hz 常用时序, 像素时钟约 25.175 MHz.
  localparam H_VISIBLE = 10'd640;
  localparam H_FRONT = 10'd16;
  localparam H_SYNC = 10'd96;
  localparam H_BACK = 10'd48;
  localparam H_TOTAL = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

  localparam V_VISIBLE = 10'd480;
  localparam V_FRONT = 10'd10;
  localparam V_SYNC = 10'd2;
  localparam V_BACK = 10'd33;
  localparam V_TOTAL = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

  wire h_last = x == H_TOTAL - 10'd1;
  wire v_last = y == V_TOTAL - 10'd1;

  assign visible = (x < H_VISIBLE) && (y < V_VISIBLE);

  // VGA 的 HS/VS 一般为低有效同步信号.
  assign hsync = ~((x >= H_VISIBLE + H_FRONT) && (x < H_VISIBLE + H_FRONT + H_SYNC));
  assign vsync = ~((y >= V_VISIBLE + V_FRONT) && (y < V_VISIBLE + V_FRONT + V_SYNC));

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x <= 10'd0;
      y <= 10'd0;
    end else if (clk_en && h_last) begin
      x <= 10'd0;
      if (v_last) begin
        y <= 10'd0;
      end else begin
        y <= y + 10'd1;
      end
    end else if (clk_en) begin
      x <= x + 10'd1;
    end
  end

endmodule
