`timescale 1ns / 1ps

// SDRAM 简单仲裁器, CPU data 优先, 然后 CPU imem, 最后 VGA 只读.
module sdram_arbiter (
    input wire clk,
    input wire rst_n,

    input wire cpu_req,
    input wire cpu_we,
    input wire [3:0] cpu_be,
    input wire [31:0] cpu_addr,
    input wire [31:0] cpu_wdata,
    output wire [31:0] cpu_rdata,
    output wire cpu_ready,

    input wire imem_req,
    input wire [31:0] imem_addr,
    output wire [31:0] imem_rdata,
    output wire imem_ready,

    input wire vga_req,
    input wire [31:0] vga_addr,
    output wire [31:0] vga_rdata,
    output wire vga_ready,

    output wire mem_req,
    output wire mem_we,
    output wire [3:0] mem_be,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    input wire [31:0] mem_rdata,
    input wire mem_ready
);

  localparam OWNER_CPU = 2'd0;
  localparam OWNER_IMEM = 2'd1;
  localparam OWNER_VGA = 2'd2;

  reg busy;
  reg [1:0] owner;
  reg req_we;
  reg [3:0] req_be;
  reg [31:0] req_addr;
  reg [31:0] req_wdata;

  wire take_cpu = !busy && cpu_req;
  wire take_imem = !busy && !cpu_req && imem_req;
  wire take_vga = !busy && !cpu_req && !imem_req && vga_req;
  wire take_any = take_cpu || take_imem || take_vga;

  assign mem_req = busy || take_any;
  assign mem_we = busy ? req_we : (take_cpu ? cpu_we : 1'b0);
  assign mem_be = busy ? req_be : (take_cpu ? cpu_be : 4'b1111);
  assign mem_addr = busy ? req_addr : (take_cpu ? cpu_addr : (take_imem ? imem_addr : vga_addr));
  assign mem_wdata = busy ? req_wdata : (take_cpu ? cpu_wdata : 32'b0);

  assign cpu_rdata = mem_rdata;
  assign imem_rdata = mem_rdata;
  assign vga_rdata = mem_rdata;
  assign cpu_ready = busy && owner == OWNER_CPU && mem_ready;
  assign imem_ready = busy && owner == OWNER_IMEM && mem_ready;
  assign vga_ready = busy && owner == OWNER_VGA && mem_ready;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy <= 1'b0;
      owner <= OWNER_CPU;
      req_we <= 1'b0;
      req_be <= 4'b0;
      req_addr <= 32'b0;
      req_wdata <= 32'b0;
    end else if (busy) begin
      if (mem_ready) begin
        busy <= 1'b0;
      end
    end else if (cpu_req) begin
      busy <= 1'b1;
      owner <= OWNER_CPU;
      req_we <= cpu_we;
      req_be <= cpu_be;
      req_addr <= cpu_addr;
      req_wdata <= cpu_wdata;
    end else if (imem_req) begin
      busy <= 1'b1;
      owner <= OWNER_IMEM;
      req_we <= 1'b0;
      req_be <= 4'b1111;
      req_addr <= imem_addr;
      req_wdata <= 32'b0;
    end else if (vga_req) begin
      busy <= 1'b1;
      owner <= OWNER_VGA;
      req_we <= 1'b0;
      req_be <= 4'b1111;
      req_addr <= vga_addr;
      req_wdata <= 32'b0;
    end
  end

endmodule
