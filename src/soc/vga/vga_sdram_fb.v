`timescale 1ns / 1ps

// VGA framebuffer 显示, framebuffer 放在 SDRAM 偏移 0x00000000.
module vga_sdram_fb #(
    parameter FRAMEBUFFER_BASE = 32'h0000_0000
) (
    input wire clk,
    input wire rst_n,

    output wire [7:0] vga_r,
    output wire [7:0] vga_g,
    output wire [7:0] vga_b,
    output wire vga_hs,
    output wire vga_vs,
    output wire vga_blank_n,
    output wire vga_sync_n,
    output wire vga_clk,

    output reg sdram_req,
    output wire [31:0] sdram_addr,
    input wire [31:0] sdram_rdata,
    input wire sdram_ready
);

  localparam FB_WIDTH = 10'd160;

  wire [9:0] x;
  wire [9:0] y;
  wire visible;

  wire [7:0] fb_x = x[9:2];
  wire [6:0] fb_y = y[8:2];
  wire [14:0] pixel_index = fb_y * FB_WIDTH + {7'b0, fb_x};
  wire [31:0] word_addr = FRAMEBUFFER_BASE + {17'b0, pixel_index[14:2], 2'b00};
  wire [1:0] byte_sel = pixel_index[1:0];

  reg [31:0] cached_word_addr;
  reg [31:0] cached_word;
  reg [31:0] pending_word_addr;
  reg cached_valid;
  reg [7:0] pixel;
  reg pixel_tick;

  wire need_read = visible && (!cached_valid || cached_word_addr != word_addr) && !sdram_req;

  vga_timing u_vga_timing (
      .clk(clk),
      .clk_en(pixel_tick),
      .rst_n(rst_n),
      .x(x),
      .y(y),
      .visible(visible),
      .hsync(vga_hs),
      .vsync(vga_vs)
  );

  assign vga_clk = pixel_tick;
  assign vga_blank_n = visible;
  assign vga_sync_n = 1'b0;
  assign sdram_addr = sdram_req ? pending_word_addr : word_addr;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pixel_tick <= 1'b0;
    end else begin
      pixel_tick <= ~pixel_tick;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sdram_req <= 1'b0;
      cached_word_addr <= 32'b0;
      cached_word <= 32'b0;
      pending_word_addr <= 32'b0;
      cached_valid <= 1'b0;
    end else if (sdram_req) begin
      if (sdram_ready) begin
        sdram_req <= 1'b0;
        cached_word_addr <= pending_word_addr;
        cached_word <= sdram_rdata;
        cached_valid <= 1'b1;
      end
    end else if (need_read) begin
      sdram_req <= 1'b1;
      pending_word_addr <= word_addr;
    end
  end

  always @(*) begin
    case (byte_sel)
      2'd0: pixel = cached_word[7:0];
      2'd1: pixel = cached_word[15:8];
      2'd2: pixel = cached_word[23:16];
      2'd3: pixel = cached_word[31:24];
      default: pixel = 8'b0;
    endcase
  end

  assign vga_r = visible ? {pixel[7:5], pixel[7:5], pixel[7:6]} : 8'b0;
  assign vga_g = visible ? {pixel[4:2], pixel[4:2], pixel[4:3]} : 8'b0;
  assign vga_b = visible ? {pixel[1:0], pixel[1:0], pixel[1:0], pixel[1:0]} : 8'b0;

endmodule
