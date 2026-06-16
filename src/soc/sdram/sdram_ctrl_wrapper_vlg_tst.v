`timescale 1ns / 1ps

module sdram_ctrl_wrapper_vlg_tst;
  reg clk;
  reg rst_n;
  reg req;
  reg we;
  reg [3:0] be;
  reg [31:0] addr;
  reg [31:0] wdata;
  wire [31:0] rdata;
  wire ready;
  wire init_done;

  wire sdram_clk;
  wire [12:0] sdram_addr;
  wire [1:0] sdram_ba;
  wire sdram_cs_n;
  wire sdram_cke;
  wire sdram_ras_n;
  wire sdram_cas_n;
  wire sdram_we_n;
  wire [1:0] sdram_dqm;
  wire [15:0] sdram_dq;

  sdram_ctrl_wrapper #(
      .INIT_WAIT_CYCLES(16'd4),
      .REFRESH_PERIOD(16'd200),
      .REFRESH_CYCLES(16'd2),
      .TRP_CYCLES(16'd1),
      .TRCD_CYCLES(16'd1),
      .CL_CYCLES(16'd3),
      .WRITE_RECOVERY_CYCLES(16'd1)
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
      .init_done(init_done),
      .sdram_clk(sdram_clk),
      .sdram_addr(sdram_addr),
      .sdram_ba(sdram_ba),
      .sdram_cs_n(sdram_cs_n),
      .sdram_cke(sdram_cke),
      .sdram_ras_n(sdram_ras_n),
      .sdram_cas_n(sdram_cas_n),
      .sdram_we_n(sdram_we_n),
      .sdram_dqm(sdram_dqm),
      .sdram_dq(sdram_dq)
  );

  sdram_model u_model (
      .clk(sdram_clk),
      .sdram_addr(sdram_addr),
      .sdram_ba(sdram_ba),
      .sdram_cs_n(sdram_cs_n),
      .sdram_cke(sdram_cke),
      .sdram_ras_n(sdram_ras_n),
      .sdram_cas_n(sdram_cas_n),
      .sdram_we_n(sdram_we_n),
      .sdram_dqm(sdram_dqm),
      .sdram_dq(sdram_dq)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task wait_ready_done;
    begin
      while (ready !== 1'b1) begin
        @(posedge clk);
      end
      #1;
    end
  endtask

  task write_word;
    input [31:0] test_addr;
    input [31:0] test_wdata;
    input [3:0] test_be;
    begin
      @(posedge clk);
      req = 1'b1;
      we = 1'b1;
      be = test_be;
      addr = test_addr;
      wdata = test_wdata;
      #1;
      if (ready !== 1'b0) begin
        $display("write should wait");
        $fatal;
      end
      wait_ready_done();
      req = 1'b0;
      we = 1'b0;
      be = 4'b0000;
      addr = 32'b0;
      wdata = 32'b0;
    end
  endtask

  task read_word;
    input [31:0] test_addr;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      @(posedge clk);
      req = 1'b1;
      we = 1'b0;
      be = 4'b1111;
      addr = test_addr;
      wdata = 32'b0;
      #1;
      if (ready !== 1'b0) begin
        $display("read should wait");
        $fatal;
      end
      wait_ready_done();
      if (rdata !== expected) begin
        $display("check %0d failed: expected %h, got %h", check_id, expected, rdata);
        $fatal;
      end
      req = 1'b0;
      be = 4'b0000;
      addr = 32'b0;
    end
  endtask

  initial begin
    rst_n = 1'b1;
    req = 1'b0;
    we = 1'b0;
    be = 4'b0000;
    addr = 32'b0;
    wdata = 32'b0;

    #1;
    rst_n = 1'b0;
    #20;
    rst_n = 1'b1;

    while (init_done !== 1'b1) begin
      @(posedge clk);
    end
    #1;

    write_word(32'h0000_0000, 32'h1122_3344, 4'b1111);
    read_word(32'h0000_0000, 32'h1122_3344, 32'd1);

    write_word(32'h0000_0000, 32'haabb_ccdd, 4'b0101);
    read_word(32'h0000_0000, 32'h11bb_33dd, 32'd2);

    write_word(32'h0000_0010, 32'h5566_7788, 4'b1111);
    read_word(32'h0000_0010, 32'h5566_7788, 32'd3);

    $display("sdram_ctrl_wrapper test passed");
    $finish;
  end

endmodule
