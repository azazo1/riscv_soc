`timescale 1ns / 1ps

module vga_pattern_vlg_tst;

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

  vga_pattern dut (
      .clk(clk),
      .clk_en(1'b1),
      .rst_n(rst_n),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .vga_hs(vga_hs),
      .vga_vs(vga_vs),
      .vga_blank_n(vga_blank_n),
      .vga_sync_n(vga_sync_n),
      .vga_clk(vga_clk)
  );

  initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;
  end

  task expect_rgb;
    input [23:0] expected;
    input [31:0] check_id;
    begin
      if ({vga_r, vga_g, vga_b} !== expected) begin
        $display("check %0d failed: rgb expected %h, got %h", check_id, expected,
                 {vga_r, vga_g, vga_b});
        $fatal;
      end
    end
  endtask

  task expect_bit;
    input actual;
    input expected;
    input [31:0] check_id;
    begin
      if (actual !== expected) begin
        $display("check %0d failed: expected %b, got %b", check_id, expected, actual);
        $fatal;
      end
    end
  endtask

  task wait_to_xy;
    input [9:0] target_x;
    input [9:0] target_y;
    integer guard;
    begin
      guard = 0;
      while ((dut.u_vga_timing.x !== target_x) || (dut.u_vga_timing.y !== target_y)) begin
        @(negedge clk);
        guard = guard + 1;
        if (guard > 500000) begin
          $display("wait_to_xy timeout: target x=%0d y=%0d", target_x, target_y);
          $fatal;
        end
      end
    end
  endtask

  initial begin
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    wait_to_xy(10'd0, 10'd0);
    #1;
    expect_bit(vga_blank_n, 1'b1, 32'd1);
    expect_bit(vga_hs, 1'b1, 32'd2);
    expect_bit(vga_vs, 1'b1, 32'd3);
    expect_bit(vga_sync_n, 1'b0, 32'd4);
    expect_rgb(24'hffffff, 32'd5);

    wait_to_xy(10'd80, 10'd0);
    #1;
    expect_rgb(24'hffff00, 32'd6);

    wait_to_xy(10'd160, 10'd0);
    #1;
    expect_rgb(24'h00ffff, 32'd7);

    wait_to_xy(10'd640, 10'd0);
    #1;
    expect_bit(vga_blank_n, 1'b0, 32'd8);
    expect_rgb(24'h000000, 32'd9);

    wait_to_xy(10'd656, 10'd0);
    #1;
    expect_bit(vga_hs, 1'b0, 32'd10);

    wait_to_xy(10'd752, 10'd0);
    #1;
    expect_bit(vga_hs, 1'b1, 32'd11);

    wait_to_xy(10'd0, 10'd490);
    #1;
    expect_bit(vga_vs, 1'b0, 32'd12);

    wait_to_xy(10'd0, 10'd492);
    #1;
    expect_bit(vga_vs, 1'b1, 32'd13);

    wait_to_xy(10'd799, 10'd524);
    @(posedge clk);
    @(negedge clk);
    #1;
    if ((dut.u_vga_timing.x !== 10'd0) || (dut.u_vga_timing.y !== 10'd0)) begin
      $display("check 14 failed: frame should wrap to x=0 y=0");
      $fatal;
    end

    $display("vga_pattern test passed");
    $finish;
  end

endmodule
