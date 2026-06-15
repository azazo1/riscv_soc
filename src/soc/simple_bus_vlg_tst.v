`timescale 1ns / 1ps

module simple_bus_vlg_tst;
  reg clk;
  reg req;
  reg we;
  reg [3:0] be;
  reg [31:0] addr;
  reg [31:0] wdata;
  wire [31:0] rdata;

  wire ram_req;
  wire ram_we;
  wire [3:0] ram_be;
  wire [31:0] ram_addr;
  wire [31:0] ram_wdata;
  reg [31:0] ram_rdata;

  simple_bus dut (
      .clk(clk),
      .req(req),
      .we(we),
      .be(be),
      .addr(addr),
      .wdata(wdata),
      .rdata(rdata),
      .ram_req(ram_req),
      .ram_we(ram_we),
      .ram_be(ram_be),
      .ram_addr(ram_addr),
      .ram_wdata(ram_wdata),
      .ram_rdata(ram_rdata)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task expect_ram_hit;
    input test_we;
    input [3:0] test_be;
    input [31:0] test_addr;
    input [31:0] test_wdata;
    input [31:0] test_ram_rdata;
    input [31:0] check_id;
    begin
      req = 1'b1;
      we = test_we;
      be = test_be;
      addr = test_addr;
      wdata = test_wdata;
      ram_rdata = test_ram_rdata;
      #1;

      if (ram_req !== 1'b1 || ram_we !== test_we || ram_be !== test_be ||
          ram_addr !== test_addr || ram_wdata !== test_wdata || rdata !== test_ram_rdata) begin
        $display("check %0d ram hit failed", check_id);
        $display("ram_req=%b ram_we=%b ram_be=%b ram_addr=%h ram_wdata=%h rdata=%h",
                 ram_req, ram_we, ram_be, ram_addr, ram_wdata, rdata);
        $fatal;
      end
    end
  endtask

  task expect_ram_miss;
    input [31:0] test_addr;
    input [31:0] check_id;
    begin
      req = 1'b1;
      we = 1'b1;
      be = 4'b1111;
      addr = test_addr;
      wdata = 32'h5566_7788;
      ram_rdata = 32'haabb_ccdd;
      #1;

      if (ram_req !== 1'b0 || rdata !== 32'b0) begin
        $display("check %0d ram miss failed: ram_req=%b rdata=%h", check_id, ram_req, rdata);
        $fatal;
      end
    end
  endtask

  initial begin
    req = 1'b0;
    we = 1'b0;
    be = 4'b0000;
    addr = 32'b0;
    wdata = 32'b0;
    ram_rdata = 32'b0;

    #1;

    expect_ram_hit(1'b0, 4'b1111, 32'h0000_0000, 32'h0000_0000, 32'h1122_3344, 32'd1);
    expect_ram_hit(1'b1, 4'b0101, 32'h0000_000c, 32'h5566_7788, 32'h99aa_bbcc, 32'd2);
    expect_ram_hit(1'b0, 4'b1111, 32'h0000_0400, 32'h0000_0000, 32'h1234_abcd, 32'd3);
    expect_ram_hit(1'b0, 4'b1111, 32'h00ff_fffc, 32'h0000_0000, 32'hdead_beef, 32'd4);

    expect_ram_miss(32'h0100_0000, 32'd5);
    expect_ram_miss(32'h1000_0000, 32'd6);

    req = 1'b0;
    we = 1'b1;
    be = 4'b1111;
    addr = 32'h0000_0000;
    wdata = 32'h1234_5678;
    ram_rdata = 32'h8765_4321;
    #1;
    if (ram_req !== 1'b0) begin
      $display("idle request should not access ram");
      $fatal;
    end

    $display("simple_bus test passed");
    $finish;
  end
endmodule
