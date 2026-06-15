`timescale 1ns / 1ps

// 最小 VGA 图案模块, 用彩条验证时序和引脚.
module vga_pattern (
    input wire clk,
    input wire clk_en,
    input wire rst_n,

    output wire [7:0] vga_r,
    output wire [7:0] vga_g,
    output wire [7:0] vga_b,
    output wire vga_hs,
    output wire vga_vs,
    output wire vga_blank_n,
    output wire vga_sync_n,
    output wire vga_clk
);

  wire [9:0] x;
  wire [9:0] y;
  wire visible;

  vga_timing u_vga_timing (
      .clk(clk),
      .clk_en(clk_en),
      .rst_n(rst_n),
      .x(x),
      .y(y),
      .visible(visible),
      .hsync(vga_hs),
      .vsync(vga_vs)
  );

  assign vga_clk = clk;
  assign vga_blank_n = visible;
  assign vga_sync_n = 1'b0;

  reg [23:0] rgb;

  always @(*) begin
    if (!visible) begin
      rgb = 24'h000000;
    end else if (x < 10'd80) begin
      rgb = 24'hffffff;
    end else if (x < 10'd160) begin
      rgb = 24'hffff00;
    end else if (x < 10'd240) begin
      rgb = 24'h00ffff;
    end else if (x < 10'd320) begin
      rgb = 24'h00ff00;
    end else if (x < 10'd400) begin
      rgb = 24'hff00ff;
    end else if (x < 10'd480) begin
      rgb = 24'hff0000;
    end else if (x < 10'd560) begin
      rgb = 24'h0000ff;
    end else begin
      rgb = 24'h000000;
    end
  end

  assign vga_r = rgb[23:16];
  assign vga_g = rgb[15:8];
  assign vga_b = rgb[7:0];

endmodule
