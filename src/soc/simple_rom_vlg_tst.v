`timescale 1ns / 1ps

module simple_rom_vlg_tst;
  reg  [31:0] addr;
  wire [31:0] rdata;

  simple_rom #(
      .ROM_WORDS(4),
      .ROM_WORD_ADDR_BITS(2),
      .ROM_FILE("firmware/test/simple_rom.hex")
  ) dut (
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
    expect_instr(32'h0000_0000, 32'h1111_1111, 32'd1);
    expect_instr(32'h0000_0002, 32'h1111_1111, 32'd2);
    expect_instr(32'h0000_0004, 32'h2222_2222, 32'd3);
    expect_instr(32'h0000_0008, 32'h3333_3333, 32'd4);
    expect_instr(32'h0000_000c, 32'h4444_4444, 32'd5);
    expect_instr(32'h0000_0010, 32'h0000_0013, 32'd6);

    $display("simple_rom test passed");
    $finish;
  end
endmodule
