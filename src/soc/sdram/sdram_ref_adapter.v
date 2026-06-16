`timescale 1ns / 1ps

`ifdef USE_SDRAM_REF_CTRL
// 把当前 SoC 的 32-bit req/ready 接口适配到 Terasic 参考 SDRAM 控制器.
// 参考控制器没有 byte enable, 所以部分字节写需要先读旧 word, 合并后再写回.
module sdram_ref_adapter #(
    parameter INIT_WAIT_CYCLES = 16'd30000
) (
    input wire clk,
    input wire rst_n,

    input wire req,
    input wire we,
    input wire [3:0] be,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output reg [31:0] rdata,
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

  localparam CPU_IDLE = 2'd0;
  localparam CPU_WAIT = 2'd1;
  localparam CPU_DONE = 2'd2;

  localparam REF_INIT_WAIT = 5'd0;
  localparam REF_IDLE = 5'd1;
  localparam REF_LOAD_READ = 5'd2;
  localparam REF_WAIT_READ_LO = 5'd3;
  localparam REF_POP_READ_LO = 5'd4;
  localparam REF_CAP_READ_LO = 5'd5;
  localparam REF_WAIT_READ_HI = 5'd6;
  localparam REF_POP_READ_HI = 5'd7;
  localparam REF_CAP_READ_HI = 5'd8;
  localparam REF_LOAD_WRITE = 5'd9;
  localparam REF_WAIT_WRITE_LO = 5'd10;
  localparam REF_DROP_WRITE_LO = 5'd11;
  localparam REF_WAIT_WRITE_HI = 5'd12;
  localparam REF_DROP_WRITE_HI = 5'd13;
  localparam REF_WAIT_WRITE_DONE = 5'd14;

  localparam [24:0] SDRAM_MAX_HALF_ADDR = 25'h1ffffff;
  localparam [15:0] WRITE_DONE_WAIT_CYCLES = 16'd128;

  reg [1:0] cpu_state;
  reg cpu_req_toggle;
  reg cpu_done_seen;
  reg ref_done_sync1;
  reg ref_done_sync2;
  reg ref_init_done_sync1;
  reg ref_init_done_sync2;

  reg cpu_we_q;
  reg [3:0] cpu_be_q;
  reg [24:0] cpu_half_addr_q;
  reg [31:0] cpu_wdata_q;

  wire ref_clk;
  wire [1:0] ref_cs_n;
  wire [15:0] ref_rd_data;
  wire ref_wr_full;
  wire ref_rd_empty;
  wire [15:0] ref_wr_use;
  wire [15:0] ref_rd_use;

  reg [4:0] ref_state;
  reg [15:0] ref_init_count;
  reg [15:0] ref_write_wait_count;
  reg ref_init_done;
  reg cpu_req_sync1;
  reg cpu_req_sync2;
  reg ref_req_seen;
  reg ref_done_toggle;
  reg ref_we_q;
  reg [3:0] ref_be_q;
  reg [24:0] ref_half_addr_q;
  reg [31:0] ref_wdata_q;
  reg [31:0] ref_write_data_q;
  reg [31:0] ref_rsp_rdata;
  reg [15:0] ref_read_lo_q;

  reg [15:0] ref_wr_data;
  reg ref_wr;
  reg [24:0] ref_wr_addr;
  reg [8:0] ref_wr_length;
  reg ref_wr_load;
  reg ref_rd;
  reg [24:0] ref_rd_addr;
  reg [8:0] ref_rd_length;
  reg ref_rd_load;

  assign ready = cpu_state == CPU_DONE;
  assign init_done = ref_init_done_sync2;
  assign sdram_cs_n = ref_cs_n[0];

  function [31:0] merge_bytes;
    input [31:0] old_data;
    input [31:0] new_data;
    input [3:0] byte_en;
    begin
      merge_bytes = old_data;
      if (byte_en[0]) begin
        merge_bytes[7:0] = new_data[7:0];
      end
      if (byte_en[1]) begin
        merge_bytes[15:8] = new_data[15:8];
      end
      if (byte_en[2]) begin
        merge_bytes[23:16] = new_data[23:16];
      end
      if (byte_en[3]) begin
        merge_bytes[31:24] = new_data[31:24];
      end
    end
  endfunction

  Sdram_Control u_sdram_control (
      .REF_CLK(clk),
      .RESET_N(rst_n),
      .CLK(ref_clk),
      .WR_DATA(ref_wr_data),
      .WR(ref_wr),
      .WR_ADDR(ref_wr_addr),
      .WR_MAX_ADDR(SDRAM_MAX_HALF_ADDR),
      .WR_LENGTH(ref_wr_length),
      .WR_LOAD(ref_wr_load),
      .WR_CLK(ref_clk),
      .WR_FULL(ref_wr_full),
      .WR_USE(ref_wr_use),
      .RD_DATA(ref_rd_data),
      .RD(ref_rd),
      .RD_ADDR(ref_rd_addr),
      .RD_MAX_ADDR(SDRAM_MAX_HALF_ADDR),
      .RD_LENGTH(ref_rd_length),
      .RD_LOAD(ref_rd_load),
      .RD_CLK(ref_clk),
      .RD_EMPTY(ref_rd_empty),
      .RD_USE(ref_rd_use),
      .SA(sdram_addr),
      .BA(sdram_ba),
      .CS_N(ref_cs_n),
      .CKE(sdram_cke),
      .RAS_N(sdram_ras_n),
      .CAS_N(sdram_cas_n),
      .WE_N(sdram_we_n),
      .DQ(sdram_dq),
      .DQM(sdram_dqm),
      .SDR_CLK(sdram_clk)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cpu_state <= CPU_IDLE;
      cpu_req_toggle <= 1'b0;
      cpu_done_seen <= 1'b0;
      ref_done_sync1 <= 1'b0;
      ref_done_sync2 <= 1'b0;
      ref_init_done_sync1 <= 1'b0;
      ref_init_done_sync2 <= 1'b0;
      cpu_we_q <= 1'b0;
      cpu_be_q <= 4'b0;
      cpu_half_addr_q <= 25'b0;
      cpu_wdata_q <= 32'b0;
      rdata <= 32'b0;
    end else begin
      ref_done_sync1 <= ref_done_toggle;
      ref_done_sync2 <= ref_done_sync1;
      ref_init_done_sync1 <= ref_init_done;
      ref_init_done_sync2 <= ref_init_done_sync1;

      case (cpu_state)
        CPU_IDLE: begin
          if (req && init_done) begin
            cpu_we_q <= we;
            cpu_be_q <= be;
            cpu_half_addr_q <= {addr[25:2], 1'b0};
            cpu_wdata_q <= wdata;
            if (we && be == 4'b0000) begin
              cpu_state <= CPU_DONE;
            end else begin
              cpu_req_toggle <= ~cpu_req_toggle;
              cpu_state <= CPU_WAIT;
            end
          end
        end

        CPU_WAIT: begin
          if (ref_done_sync2 != cpu_done_seen) begin
            cpu_done_seen <= ref_done_sync2;
            rdata <= ref_rsp_rdata;
            cpu_state <= CPU_DONE;
          end
        end

        CPU_DONE: begin
          cpu_state <= CPU_IDLE;
        end

        default: begin
          cpu_state <= CPU_IDLE;
        end
      endcase
    end
  end

  always @(posedge ref_clk or negedge rst_n) begin
    if (!rst_n) begin
      ref_state <= REF_INIT_WAIT;
      ref_init_count <= INIT_WAIT_CYCLES[15:0];
      ref_write_wait_count <= 16'b0;
      ref_init_done <= 1'b0;
      cpu_req_sync1 <= 1'b0;
      cpu_req_sync2 <= 1'b0;
      ref_req_seen <= 1'b0;
      ref_done_toggle <= 1'b0;
      ref_we_q <= 1'b0;
      ref_be_q <= 4'b0;
      ref_half_addr_q <= 25'b0;
      ref_wdata_q <= 32'b0;
      ref_write_data_q <= 32'b0;
      ref_rsp_rdata <= 32'b0;
      ref_read_lo_q <= 16'b0;
      ref_wr_data <= 16'b0;
      ref_wr <= 1'b0;
      ref_wr_addr <= 25'b0;
      ref_wr_length <= 9'b0;
      ref_wr_load <= 1'b1;
      ref_rd <= 1'b0;
      ref_rd_addr <= 25'b0;
      ref_rd_length <= 9'b0;
      ref_rd_load <= 1'b1;
    end else begin
      cpu_req_sync1 <= cpu_req_toggle;
      cpu_req_sync2 <= cpu_req_sync1;
      ref_wr <= 1'b0;
      ref_rd <= 1'b0;

      case (ref_state)
        REF_INIT_WAIT: begin
          ref_wr_load <= 1'b1;
          ref_rd_load <= 1'b1;
          ref_wr_length <= 9'b0;
          ref_rd_length <= 9'b0;
          if (ref_init_count == 16'b0) begin
            ref_init_done <= 1'b1;
            ref_state <= REF_IDLE;
          end else begin
            ref_init_count <= ref_init_count - 16'd1;
          end
        end

        REF_IDLE: begin
          ref_wr_load <= 1'b1;
          ref_rd_load <= 1'b1;
          ref_wr_length <= 9'b0;
          ref_rd_length <= 9'b0;
          ref_write_wait_count <= 16'b0;
          if (cpu_req_sync2 != ref_req_seen) begin
            ref_req_seen <= cpu_req_sync2;
            ref_we_q <= cpu_we_q;
            ref_be_q <= cpu_be_q;
            ref_half_addr_q <= cpu_half_addr_q;
            ref_wdata_q <= cpu_wdata_q;
            if (cpu_we_q && cpu_be_q == 4'b1111) begin
              ref_write_data_q <= cpu_wdata_q;
              ref_wr_addr <= cpu_half_addr_q;
              ref_wr_length <= 9'd2;
              ref_wr_load <= 1'b1;
              ref_state <= REF_LOAD_WRITE;
            end else begin
              ref_rd_addr <= cpu_half_addr_q;
              ref_rd_length <= 9'd2;
              ref_rd_load <= 1'b1;
              ref_state <= REF_LOAD_READ;
            end
          end
        end

        REF_LOAD_READ: begin
          ref_rd_load <= 1'b0;
          ref_rd_length <= 9'd2;
          ref_state <= REF_WAIT_READ_LO;
        end

        REF_WAIT_READ_LO: begin
          ref_rd_load <= 1'b0;
          ref_rd_length <= 9'd2;
          if (!ref_rd_empty) begin
            ref_rd <= 1'b1;
            ref_state <= REF_POP_READ_LO;
          end
        end

        REF_POP_READ_LO: begin
          ref_rd_load <= 1'b0;
          ref_rd_length <= 9'd2;
          ref_state <= REF_CAP_READ_LO;
        end

        REF_CAP_READ_LO: begin
          ref_rd_load <= 1'b0;
          ref_rd_length <= 9'd2;
          ref_read_lo_q <= ref_rd_data;
          ref_state <= REF_WAIT_READ_HI;
        end

        REF_WAIT_READ_HI: begin
          ref_rd_load <= 1'b0;
          ref_rd_length <= 9'd2;
          if (!ref_rd_empty) begin
            ref_rd <= 1'b1;
            ref_state <= REF_POP_READ_HI;
          end
        end

        REF_POP_READ_HI: begin
          ref_rd_load <= 1'b0;
          ref_rd_length <= 9'd2;
          ref_state <= REF_CAP_READ_HI;
        end

        REF_CAP_READ_HI: begin
          ref_rd_load <= 1'b1;
          ref_rd_length <= 9'b0;
          ref_rsp_rdata <= {ref_rd_data, ref_read_lo_q};
          if (ref_we_q) begin
            ref_write_data_q <= merge_bytes({ref_rd_data, ref_read_lo_q}, ref_wdata_q, ref_be_q);
            ref_wr_addr <= ref_half_addr_q;
            ref_wr_length <= 9'd2;
            ref_wr_load <= 1'b1;
            ref_state <= REF_LOAD_WRITE;
          end else begin
            ref_done_toggle <= ~ref_done_toggle;
            ref_state <= REF_IDLE;
          end
        end

        REF_LOAD_WRITE: begin
          ref_wr_load <= 1'b0;
          ref_wr_length <= 9'd2;
          ref_state <= REF_WAIT_WRITE_LO;
        end

        REF_WAIT_WRITE_LO: begin
          ref_wr_load <= 1'b0;
          ref_wr_length <= 9'd2;
          if (!ref_wr_full) begin
            ref_wr_data <= ref_write_data_q[15:0];
            ref_wr <= 1'b1;
            ref_state <= REF_DROP_WRITE_LO;
          end
        end

        REF_DROP_WRITE_LO: begin
          ref_wr_load <= 1'b0;
          ref_wr_length <= 9'd2;
          ref_state <= REF_WAIT_WRITE_HI;
        end

        REF_WAIT_WRITE_HI: begin
          ref_wr_load <= 1'b0;
          ref_wr_length <= 9'd2;
          if (!ref_wr_full) begin
            ref_wr_data <= ref_write_data_q[31:16];
            ref_wr <= 1'b1;
            ref_state <= REF_DROP_WRITE_HI;
          end
        end

        REF_DROP_WRITE_HI: begin
          ref_wr_load <= 1'b0;
          ref_wr_length <= 9'd2;
          ref_state <= REF_WAIT_WRITE_DONE;
        end

        REF_WAIT_WRITE_DONE: begin
          ref_wr_load <= 1'b0;
          ref_wr_length <= 9'd2;
          ref_write_wait_count <= ref_write_wait_count + 16'd1;
          if (ref_write_wait_count == WRITE_DONE_WAIT_CYCLES) begin
            ref_wr_load <= 1'b1;
            ref_wr_length <= 9'b0;
            ref_done_toggle <= ~ref_done_toggle;
            ref_state <= REF_IDLE;
          end
        end

        default: begin
          ref_state <= REF_INIT_WAIT;
        end
      endcase
    end
  end

endmodule
`endif
