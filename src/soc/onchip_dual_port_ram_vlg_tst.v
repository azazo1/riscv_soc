`timescale 1ns / 1ps

module onchip_dual_port_ram_vlg_tst;
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

  onchip_dual_port_ram #(
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

  always #5 clk = ~clk;

  task fail;
    input [8 * 80 - 1:0] msg;
    begin
      $display("FAIL: %0s", msg);
      $finish;
    end
  endtask

  task data_access;
    input is_write;
    input [3:0] byte_en;
    input [31:0] access_addr;
    input [31:0] write_data;
    input [31:0] expect_data;
    input check_data;
    begin
      @(negedge clk);
      req = 1'b1;
      we = is_write;
      be = byte_en;
      addr = access_addr;
      wdata = write_data;

      @(posedge clk);
      #1;
      if (ready !== 1'b0) begin
        fail("data port should wait for registered RAM output");
      end

      @(posedge clk);
      #1;
      if (ready !== 1'b1) begin
        fail("data port should respond after two clocks");
      end
      if (check_data && rdata !== expect_data) begin
        fail("data port read data mismatch");
      end

      @(negedge clk);
      req = 1'b0;
      we = 1'b0;
      be = 4'b0000;
      addr = 32'b0;
      wdata = 32'b0;

      @(posedge clk);
      #1;
    end
  endtask

  task fetch_once;
    input [31:0] fetch_addr;
    input [31:0] expect_instr;
    begin
      @(negedge clk);
      imem_req = 1'b1;
      imem_addr = fetch_addr;

      @(posedge clk);
      #1;
      if (imem_ready !== 1'b0) begin
        fail("imem port should wait for registered RAM output");
      end

      @(posedge clk);
      #1;
      if (imem_ready !== 1'b1) begin
        fail("imem port should become ready after two clocks");
      end
      if (imem_rdata !== expect_instr) begin
        fail("imem read data mismatch");
      end

      @(negedge clk);
      imem_req = 1'b0;
      imem_addr = 32'b0;

      @(posedge clk);
      #1;
    end
  endtask

  initial begin
    clk = 1'b0;
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
    @(posedge clk);

    data_access(1'b1, 4'b1111, 32'h0000_0000, 32'h1122_3344, 32'b0, 1'b0);
    data_access(1'b0, 4'b0000, 32'h0000_0000, 32'b0, 32'h1122_3344, 1'b1);

    data_access(1'b1, 4'b0101, 32'h0000_0000, 32'haabb_ccdd, 32'b0, 1'b0);
    data_access(1'b0, 4'b0000, 32'h0000_0000, 32'b0, 32'h11bb_33dd, 1'b1);

    data_access(1'b1, 4'b1111, 32'h0000_0004, 32'h5566_7788, 32'b0, 1'b0);
    fetch_once(32'h0000_0000, 32'h11bb_33dd);

    @(negedge clk);
    imem_req = 1'b1;
    imem_addr = 32'h0000_0000;

    @(posedge clk);
    @(posedge clk);
    #1;
    if (imem_ready !== 1'b1 || imem_rdata !== 32'h11bb_33dd) begin
      fail("first continuous imem fetch mismatch");
    end

    @(negedge clk);
    imem_addr = 32'h0000_0004;
    #1;
    if (imem_ready !== 1'b0) begin
      fail("imem should wait when fetch address changes");
    end

    @(posedge clk);
    #1;
    if (imem_ready !== 1'b0) begin
      fail("imem should still wait on address change");
    end

    @(posedge clk);
    #1;
    if (imem_ready !== 1'b1 || imem_rdata !== 32'h5566_7788) begin
      fail("second continuous imem fetch mismatch");
    end

    @(negedge clk);
    imem_req = 1'b0;
    imem_addr = 32'b0;

    $display("onchip_dual_port_ram test passed");
    $finish;
  end

endmodule
