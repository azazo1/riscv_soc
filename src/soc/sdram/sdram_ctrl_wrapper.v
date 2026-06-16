`timescale 1ns / 1ps

// SDRAM 控制器入口.
// 默认使用本项目的简单控制器, Quartus 打开 USE_SDRAM_REF_CTRL 后切到参考控制器适配路径.
module sdram_ctrl_wrapper #(
    parameter INIT_WAIT_CYCLES = 16'd12000,
    parameter REFRESH_PERIOD = 16'd512,
    parameter REFRESH_CYCLES = 16'd8,
    parameter TRP_CYCLES = 16'd3,
    parameter TRCD_CYCLES = 16'd3,
    parameter CL_CYCLES = 16'd3,
    parameter WRITE_RECOVERY_CYCLES = 16'd3,
    parameter SDRAM_WORD_ADDR_BITS = 24
) (
    input wire clk,
    input wire rst_n,

    input wire req,
    input wire we,
    input wire [3:0] be,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output wire [31:0] rdata,
    output wire ready,
    output wire init_done,

    output wire sdram_clk,
    output wire [12:0] sdram_addr,
    output wire [1:0] sdram_ba,
    output wire sdram_cs_n,
    output wire sdram_cke,
    output wire sdram_ras_n,
    output wire sdram_cas_n,
    output wire sdram_we_n,
    output wire [1:0] sdram_dqm,
    inout wire [15:0] sdram_dq
);

`ifdef USE_SDRAM_REF_CTRL
  sdram_ref_adapter #(
      // 参考 PLL 路径内部控制时钟是 100 MHz, 比板上输入 clk 快一倍.
      .INIT_WAIT_CYCLES(INIT_WAIT_CYCLES * 2)
  ) u_sdram_ref_adapter (
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
`else
  sdram_simple_ctrl #(
      .INIT_WAIT_CYCLES(INIT_WAIT_CYCLES),
      .REFRESH_PERIOD(REFRESH_PERIOD),
      .REFRESH_CYCLES(REFRESH_CYCLES),
      .TRP_CYCLES(TRP_CYCLES),
      .TRCD_CYCLES(TRCD_CYCLES),
      .CL_CYCLES(CL_CYCLES),
      .WRITE_RECOVERY_CYCLES(WRITE_RECOVERY_CYCLES),
      .SDRAM_WORD_ADDR_BITS(SDRAM_WORD_ADDR_BITS)
  ) u_sdram_simple_ctrl (
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
`endif

endmodule
