`timescale 1ns / 1ps

module simple_dual_port_ram_vlg_tst;
  reg clk;
  reg rst_n;
  reg req;
  reg we;
  reg [3:0] be;
  reg [31:0] addr;
  reg [31:0] wdata;
  wire [31:0] rdata;
  wire ready;
  reg imem_req;
  reg [31:0] imem_addr;
  wire [31:0] imem_rdata;
  wire imem_ready;

  simple_dual_port_ram #(
      .RAM_WORDS(16),
      .RAM_WORD_ADDR_BITS(4)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .req(req),
      .we(we),
      .be(be),
      .addr(addr),
      .wdata(wdata),
      .rdata(rdata),
      .ready(ready),
      .imem_req(imem_req),
      .imem_addr(imem_addr),
      .imem_rdata(imem_rdata),
      .imem_ready(imem_ready)
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

  task write_word;
    input [31:0] write_addr;
    input [31:0] write_data;
    input [3:0] write_be;
    begin
      req = 1'b1;
      we = 1'b1;
      be = write_be;
      addr = write_addr;
      wdata = write_data;
      #1;
      expect_value({31'b0, ready}, 32'h0000_0000, 32'd1);
      @(posedge clk);
      #1;
      expect_value({31'b0, ready}, 32'h0000_0001, 32'd2);
      @(posedge clk);
      #1;
      req = 1'b0;
      we = 1'b0;
    end
  endtask

  task read_word;
    input [31:0] read_addr;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      req = 1'b1;
      we = 1'b0;
      be = 4'b1111;
      addr = read_addr;
      wdata = 32'b0;
      #1;
      if (ready !== 1'b0) begin
        $display("check %0d failed: read should wait first cycle", check_id);
        $fatal;
      end
      @(posedge clk);
      #1;
      if (ready !== 1'b1 || rdata !== expected) begin
        $display("check %0d failed: expected ready data %h, got ready=%b data=%h", check_id, expected, ready, rdata);
        $fatal;
      end
      @(posedge clk);
      #1;
      req = 1'b0;
    end
  endtask

  task fetch_word;
    input [31:0] fetch_addr;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      imem_req = 1'b1;
      imem_addr = fetch_addr;
      #1;
      if (imem_ready !== 1'b0) begin
        $display("check %0d failed: imem should wait first cycle", check_id);
        $fatal;
      end
      @(posedge clk);
      #1;
      if (imem_ready !== 1'b1 || imem_rdata !== expected) begin
        $display("check %0d failed: expected imem %h, got ready=%b data=%h", check_id, expected, imem_ready, imem_rdata);
        $fatal;
      end
      imem_req = 1'b0;
      #1;
    end
  endtask

  initial begin
    rst_n = 1'b0;
    req = 1'b0;
    we = 1'b0;
    be = 4'b0000;
    addr = 32'b0;
    wdata = 32'b0;
    imem_req = 1'b0;
    imem_addr = 32'b0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    #1;

    write_word(32'h0000_0000, 32'h1122_3344, 4'b1111);
    read_word(32'h0000_0000, 32'h1122_3344, 32'd3);

    write_word(32'h0000_0004, 32'haabb_ccdd, 4'b1111);
    read_word(32'h0000_0004, 32'haabb_ccdd, 32'd4);

    write_word(32'h0000_0004, 32'h0000_00ee, 4'b0001);
    read_word(32'h0000_0004, 32'haabb_ccee, 32'd5);

    fetch_word(32'h0000_0000, 32'h1122_3344, 32'd6);
    fetch_word(32'h0000_0004, 32'haabb_ccee, 32'd7);

    $display("simple_dual_port_ram test passed");
    $finish;
  end
endmodule
