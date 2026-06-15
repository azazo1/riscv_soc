`timescale 1ns / 1ps

// 简单 soc 实现
module rv32i_soc #(
    parameter RESET_PC = 32'h0000_0000
) (
    input wire clk,
    input wire rst_n
);

  wire dmem_req;
  wire dmem_we;
  wire [3:0] dmem_be;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  wire [31:0] dmem_rdata;

  wire [31:0] imem_addr;
  wire [31:0] imem_rdata;


  simple_ram u_ram (
      .clk(clk),
      .req(dmem_req),
      .we(dmem_we),
      .be(dmem_be),
      .addr(dmem_addr),
      .wdata(dmem_wdata),
      .rdata(dmem_rdata)
  );

  simple_rom u_rom (
      .addr (imem_addr),
      .rdata(imem_rdata)
  );

  rv32i_core #(
      .RESET_PC(RESET_PC)
  ) u_core (
      .clk  (clk),
      .rst_n(rst_n),

      .imem_addr (imem_addr),
      .imem_rdata(imem_rdata),

      .dmem_req(dmem_req),
      .dmem_we(dmem_we),
      .dmem_be(dmem_be),
      .dmem_addr(dmem_addr),
      .dmem_wdata(dmem_wdata),
      .dmem_rdata(dmem_rdata)
  );

endmodule
