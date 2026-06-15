`timescale 1ns / 1ps

module de1_soc_top_vlg_tst;
  reg clk;
  reg [9:0] sw;
  reg [3:0] key;
  wire [9:0] ledr;
  wire [6:0] hex0;
  wire [6:0] hex1;
  wire [6:0] hex2;
  wire [6:0] hex3;
  wire [6:0] hex4;
  wire [6:0] hex5;

  de1_soc_top dut (
      .clk(clk),
      .sw(sw),
      .key(key),
      .ledr(ledr),
      .hex0(hex0),
      .hex1(hex1),
      .hex2(hex2),
      .hex3(hex3),
      .hex4(hex4),
      .hex5(hex5)
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
    sw = 10'h355;
    key = 4'b1111;

    #1;
    #20;
    expect_value(dut.u_soc.u_core.u_pc_reg.pc, 32'h0000_0000, 32'd1);
    expect_value({22'b0, ledr}, 32'h0000_0000, 32'd2);
    expect_value({25'b0, hex0}, 32'h0000_007f, 32'd3);

    sw[9] = 1'b0;  // SW9=0 后 CPU 开始从 ROM 执行.
    repeat (120) @(posedge clk);
    #1;

    expect_value({22'b0, ledr}, 32'h0000_000f, 32'd4);
    expect_value(dut.u_soc.u_core.u_regfile.regs[30], 32'h0000_0000, 32'd5);
    expect_value(dut.u_soc.u_core.u_regfile.regs[31], 32'h0000_000f, 32'd6);
    expect_value(dut.u_soc.u_ram.ram_data[32], 32'h1234_5678, 32'd7);
    expect_value({1'b0, hex3, 1'b0, hex2, 1'b0, hex1, 1'b0, hex0}, 32'h7f7f_7f40, 32'd8);
    expect_value({16'b0, 1'b0, hex5, 1'b0, hex4}, 32'h0000_7f7f, 32'd9);

    sw[9] = 1'b1;  // SW9=1 时 PC 回到 RESET_PC.
    #10;
    expect_value(dut.u_soc.u_core.u_pc_reg.pc, 32'h0000_0000, 32'd10);

    $display("de1_soc_top test passed");
    $finish;
  end
endmodule
