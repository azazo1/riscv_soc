`timescale 1ns / 1ps

module rv32i_soc_vlg_tst;
  reg clk;
  reg rst_n;
  reg [9:0] sw;
  reg [3:0] key;
  wire [9:0] ledr;
  wire [6:0] hex0;
  wire [6:0] hex1;
  wire [6:0] hex2;
  wire [6:0] hex3;
  wire [6:0] hex4;
  wire [6:0] hex5;
  wire [6:0] hex6;
  wire [6:0] hex7;

  rv32i_soc dut (
      .clk(clk),
      .rst_n(rst_n),
      .sw(sw),
      .key(key),
      .ledr(ledr),
      .hex0(hex0),
      .hex1(hex1),
      .hex2(hex2),
      .hex3(hex3),
      .hex4(hex4),
      .hex5(hex5),
      .hex6(hex6),
      .hex7(hex7)
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
    rst_n = 1'b1;
    sw = 10'b0;
    key = 4'b1111;
    #1;
    rst_n = 1'b0;
    #20;
    rst_n = 1'b1;

    repeat (20) @(posedge clk);
    #1;

    expect_value(dut.u_core.u_regfile.regs[1], 32'd5, 32'd1);
    expect_value(dut.u_core.u_regfile.regs[2], 32'd7, 32'd2);
    expect_value(dut.u_core.u_regfile.regs[3], 32'd12, 32'd3);
    expect_value(dut.u_core.u_regfile.regs[4], 32'd12, 32'd4);
    expect_value(dut.u_core.u_regfile.regs[5], 32'd2, 32'd5);
    expect_value(dut.u_ram.ram_data[0], 32'd12, 32'd6);
    expect_value(dut.u_core.u_pc_reg.pc, 32'h0000_0020, 32'd7);

    $display("rv32i_soc test passed");
    $finish;
  end
endmodule
