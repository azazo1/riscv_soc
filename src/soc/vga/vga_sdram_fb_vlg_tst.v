`timescale 1ns / 1ps

module vga_sdram_fb_vlg_tst;

  reg clk;
  reg rst_n;
  wire [7:0] vga_r;
  wire [7:0] vga_g;
  wire [7:0] vga_b;
  wire vga_hs;
  wire vga_vs;
  wire vga_blank_n;
  wire vga_sync_n;
  wire vga_clk;
  wire sdram_req;
  wire [31:0] sdram_addr;
  reg [31:0] sdram_rdata;
  reg sdram_ready;

  vga_sdram_fb dut (
      .clk(clk),
      .rst_n(rst_n),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .vga_hs(vga_hs),
      .vga_vs(vga_vs),
      .vga_blank_n(vga_blank_n),
      .vga_sync_n(vga_sync_n),
      .vga_clk(vga_clk),
      .sdram_req(sdram_req),
      .sdram_addr(sdram_addr),
      .sdram_rdata(sdram_rdata),
      .sdram_ready(sdram_ready)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task expect_value;
    input [31:0] actual;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      if (actual !== expected) begin
        $display("check %0d failed: expected %h, got %h", check_id, expected, actual);
        $fatal;
      end
    end
  endtask

  initial begin
    integer i;
    reg seen_next_word;

    rst_n = 1'b0;
    sdram_rdata = 32'h0000_0000;
    sdram_ready = 1'b0;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    wait (sdram_req === 1'b1);
    #1;
    expect_value(sdram_addr, 32'h0000_0000, 32'd1);

    sdram_rdata = 32'hffeeddcc;
    @(negedge clk);
    sdram_ready = 1'b1;
    @(negedge clk);
    sdram_ready = 1'b0;

    wait (dut.cached_valid === 1'b1);
    @(negedge clk);
    #1;
    expect_value({31'b0, vga_blank_n}, 32'h0000_0001, 32'd2);
    expect_value({8'b0, vga_r, vga_g, vga_b}, 32'h00db6d00, 32'd3);

    seen_next_word = 1'b0;
    for (i = 0; i < 64; i = i + 1) begin
      @(negedge clk);
      if (sdram_req === 1'b1 && sdram_addr === 32'h0000_0004) begin
        seen_next_word = 1'b1;
      end
    end
    if (!seen_next_word) begin
      $display("check 4 failed: next framebuffer word was not requested");
      $fatal;
    end

    $display("vga_sdram_fb test passed");
    $finish;
  end

endmodule
