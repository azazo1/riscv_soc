`timescale 1ns / 1ps

module simple_rom_vlg_tst;
  reg  [31:0] addr;
  wire [31:0] rdata;

  simple_rom dut (
      .addr(addr),
      .rdata(rdata)
  );

  task expect_instr;
    input [31:0] test_addr;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      addr = test_addr;
      #1;
      if (rdata !== expected) begin
        $display("check %0d failed at addr %h: expected %h, got %h", check_id, test_addr, expected, rdata);
        $fatal;
      end
    end
  endtask

  initial begin
    expect_instr(32'h0000_0000, 32'h0100_00b7, 32'd1);
    expect_instr(32'h0000_0004, 32'h3024_8137, 32'd2);
    expect_instr(32'h0000_0008, 32'h9401_0113, 32'd3);
    expect_instr(32'h0000_000c, 32'h0020_a623, 32'd4);
    expect_instr(32'h0000_0010, 32'h7802_11b7, 32'd5);
    expect_instr(32'h0000_0014, 32'h2191_8193, 32'd6);
    expect_instr(32'h0000_0018, 32'h0030_a823, 32'd7);
    expect_instr(32'h0000_001c, 32'h0040_a203, 32'd8);
    expect_instr(32'h0000_0020, 32'h0040_a023, 32'd9);
    expect_instr(32'h0000_0024, 32'hfe00_0ce3, 32'd10);
    expect_instr(32'h0000_0028, 32'h0000_0013, 32'd11);

    $display("simple_rom test passed");
    $finish;
  end
endmodule
