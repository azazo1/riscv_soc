`timescale 1ns / 1ps

// 很小的 SDRAM 行为模型, 只用于本项目 testbench.
// 它识别 ACT, READ, WRITE, PRECHARGE, REFRESH, LOAD MODE 这些命令.
module sdram_model #(
    parameter MEM_WORDS = 4096,
    parameter MEM_ADDR_BITS = 12,
    parameter CL_CYCLES = 3
) (
    input wire clk,
    input wire [12:0] sdram_addr,
    input wire [1:0] sdram_ba,
    input wire sdram_cs_n,
    input wire sdram_cke,
    input wire sdram_ras_n,
    input wire sdram_cas_n,
    input wire sdram_we_n,
    input wire [1:0] sdram_dqm,
    inout wire [15:0] sdram_dq
);

  reg [15:0] mem[0:MEM_WORDS-1];
  reg [12:0] open_row[0:3];
  reg row_open[0:3];
  reg [15:0] dq_out;
  reg dq_oe;
  reg [MEM_ADDR_BITS-1:0] read_addr_pipe[0:CL_CYCLES-1];
  reg [CL_CYCLES-1:0] read_valid_pipe;
  integer i;

  wire cmd_active = sdram_cke && !sdram_cs_n && !sdram_ras_n && sdram_cas_n && sdram_we_n;
  wire cmd_read = sdram_cke && !sdram_cs_n && sdram_ras_n && !sdram_cas_n && sdram_we_n;
  wire cmd_write = sdram_cke && !sdram_cs_n && sdram_ras_n && !sdram_cas_n && !sdram_we_n;
  wire cmd_precharge = sdram_cke && !sdram_cs_n && !sdram_ras_n && sdram_cas_n && !sdram_we_n;

  wire [24:0] half_addr = {sdram_ba, open_row[sdram_ba], sdram_addr[9:0]};
  wire [MEM_ADDR_BITS-1:0] mem_addr = half_addr[MEM_ADDR_BITS-1:0];

  assign sdram_dq = dq_oe ? dq_out : 16'hzzzz;

  initial begin
    for (i = 0; i < MEM_WORDS; i = i + 1) begin
      mem[i] = 16'b0;
    end
    for (i = 0; i < 4; i = i + 1) begin
      open_row[i] = 13'b0;
      row_open[i] = 1'b0;
    end
    for (i = 0; i < CL_CYCLES; i = i + 1) begin
      read_addr_pipe[i] = {MEM_ADDR_BITS{1'b0}};
    end
    read_valid_pipe = {CL_CYCLES{1'b0}};
    dq_out = 16'b0;
    dq_oe = 1'b0;
  end

  always @(posedge clk) begin
    dq_oe <= 1'b0;
    read_valid_pipe <= {read_valid_pipe[CL_CYCLES-2:0], 1'b0};
    read_addr_pipe[0] <= mem_addr;
    for (i = 1; i < CL_CYCLES; i = i + 1) begin
      read_addr_pipe[i] <= read_addr_pipe[i-1];
    end

    if (read_valid_pipe[CL_CYCLES-1]) begin
      dq_out <= mem[read_addr_pipe[CL_CYCLES-1]];
      dq_oe <= 1'b1;
    end

    if (cmd_active) begin
      open_row[sdram_ba] <= sdram_addr;
      row_open[sdram_ba] <= 1'b1;
    end

    if (cmd_read && row_open[sdram_ba]) begin
      read_valid_pipe[0] <= 1'b1;
      if (sdram_addr[10]) begin
        row_open[sdram_ba] <= 1'b0;
      end
    end

    if (cmd_write && row_open[sdram_ba]) begin
      if (!sdram_dqm[0]) begin
        mem[mem_addr][7:0] <= sdram_dq[7:0];
      end
      if (!sdram_dqm[1]) begin
        mem[mem_addr][15:8] <= sdram_dq[15:8];
      end
      if (sdram_addr[10]) begin
        row_open[sdram_ba] <= 1'b0;
      end
    end

    if (cmd_precharge) begin
      if (sdram_addr[10]) begin
        for (i = 0; i < 4; i = i + 1) begin
          row_open[i] <= 1'b0;
        end
      end else begin
        row_open[sdram_ba] <= 1'b0;
      end
    end
  end

endmodule
