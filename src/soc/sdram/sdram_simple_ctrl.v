`timescale 1ns / 1ps

// 简单 SDRAM 控制器, 面向 DE1-SoC 板载 64 MiB 16-bit SDRAM.
// CPU 侧是一次请求一次完成的 32-bit 小端接口.
module sdram_simple_ctrl #(
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
    output reg [31:0] rdata,
    output reg ready,
    output reg init_done,

    output wire sdram_clk,
    output reg [12:0] sdram_addr,
    output reg [1:0] sdram_ba,
    output reg sdram_cs_n,
    output reg sdram_cke,
    output reg sdram_ras_n,
    output reg sdram_cas_n,
    output reg sdram_we_n,
    output reg [1:0] sdram_dqm,
    inout wire [15:0] sdram_dq
);

  localparam CMD_MODE = 13'b000_0_00_011_0_000;

  localparam STATE_INIT_WAIT = 5'd0;
  localparam STATE_INIT_PRE = 5'd1;
  localparam STATE_INIT_PRE_WAIT = 5'd2;
  localparam STATE_INIT_REF1 = 5'd3;
  localparam STATE_INIT_REF1_WAIT = 5'd4;
  localparam STATE_INIT_REF2 = 5'd5;
  localparam STATE_INIT_REF2_WAIT = 5'd6;
  localparam STATE_INIT_MODE = 5'd7;
  localparam STATE_INIT_MODE_WAIT = 5'd8;
  localparam STATE_IDLE = 5'd9;
  localparam STATE_REFRESH = 5'd10;
  localparam STATE_REFRESH_WAIT = 5'd11;
  localparam STATE_ACT = 5'd12;
  localparam STATE_RCD_WAIT = 5'd13;
  localparam STATE_READ_LO = 5'd14;
  localparam STATE_READ_LO_WAIT = 5'd15;
  localparam STATE_READ_HI = 5'd16;
  localparam STATE_READ_HI_WAIT = 5'd17;
  localparam STATE_WRITE_LO = 5'd18;
  localparam STATE_WRITE_HI = 5'd19;
  localparam STATE_WRITE_WAIT = 5'd20;
  localparam STATE_DONE = 5'd21;

  reg [4:0] state;
  reg [15:0] wait_count;
  reg [15:0] refresh_count;
  reg [2:0] init_refresh_count;
  reg [SDRAM_WORD_ADDR_BITS-1:0] req_word_addr;
  reg [31:0] req_wdata;
  reg [3:0] req_be;
  reg req_we;
  reg [15:0] dq_out;
  reg dq_oe;

  wire [SDRAM_WORD_ADDR_BITS-1:0] word_addr = addr[SDRAM_WORD_ADDR_BITS+1:2];
  wire [SDRAM_WORD_ADDR_BITS:0] half_addr_lo = {req_word_addr, 1'b0};
  wire [SDRAM_WORD_ADDR_BITS:0] half_addr_hi = {req_word_addr, 1'b1};
  wire [12:0] row_addr = half_addr_lo[22:10];
  wire [1:0] bank_addr = half_addr_lo[24:23];
  wire [9:0] col_addr_lo = half_addr_lo[9:0];
  wire [9:0] col_addr_hi = half_addr_hi[9:0];

  assign sdram_clk = ~clk;
  assign sdram_dq = dq_oe ? dq_out : 16'hzzzz;

  always @(*) begin
    ready = (state == STATE_DONE);
  end

  task command_nop;
    begin
      sdram_cs_n  = 1'b0;
      sdram_ras_n = 1'b1;
      sdram_cas_n = 1'b1;
      sdram_we_n  = 1'b1;
    end
  endtask

  task command_precharge_all;
    begin
      sdram_cs_n   = 1'b0;
      sdram_ras_n  = 1'b0;
      sdram_cas_n  = 1'b1;
      sdram_we_n   = 1'b0;
      sdram_addr   = 13'b0;
      sdram_addr[10] = 1'b1;
      sdram_ba     = 2'b00;
    end
  endtask

  task command_refresh;
    begin
      sdram_cs_n  = 1'b0;
      sdram_ras_n = 1'b0;
      sdram_cas_n = 1'b0;
      sdram_we_n  = 1'b1;
      sdram_addr  = 13'b0;
      sdram_ba    = 2'b00;
    end
  endtask

  task command_load_mode;
    begin
      sdram_cs_n  = 1'b0;
      sdram_ras_n = 1'b0;
      sdram_cas_n = 1'b0;
      sdram_we_n  = 1'b0;
      sdram_addr  = CMD_MODE;
      sdram_ba    = 2'b00;
    end
  endtask

  task command_activate;
    begin
      sdram_cs_n  = 1'b0;
      sdram_ras_n = 1'b0;
      sdram_cas_n = 1'b1;
      sdram_we_n  = 1'b1;
      sdram_addr  = row_addr;
      sdram_ba    = bank_addr;
    end
  endtask

  task command_read;
    input high_half;
    input auto_precharge;
    begin
      sdram_cs_n   = 1'b0;
      sdram_ras_n  = 1'b1;
      sdram_cas_n  = 1'b0;
      sdram_we_n   = 1'b1;
      sdram_addr   = {3'b000, high_half ? col_addr_hi : col_addr_lo};
      sdram_addr[10] = auto_precharge;
      sdram_ba     = bank_addr;
      sdram_dqm    = 2'b00;
    end
  endtask

  task command_write;
    input high_half;
    input auto_precharge;
    input [15:0] data;
    input [1:0] mask;
    begin
      sdram_cs_n   = 1'b0;
      sdram_ras_n  = 1'b1;
      sdram_cas_n  = 1'b0;
      sdram_we_n   = 1'b0;
      sdram_addr   = {3'b000, high_half ? col_addr_hi : col_addr_lo};
      sdram_addr[10] = auto_precharge;
      sdram_ba     = bank_addr;
      sdram_dqm    = mask;
      dq_out       = data;
      dq_oe        = 1'b1;
    end
  endtask

  task load_wait;
    input [15:0] value;
    begin
      wait_count <= value;
    end
  endtask

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_INIT_WAIT;
      wait_count <= INIT_WAIT_CYCLES;
      refresh_count <= REFRESH_PERIOD;
      init_refresh_count <= 3'b0;
      req_word_addr <= {SDRAM_WORD_ADDR_BITS{1'b0}};
      req_wdata <= 32'b0;
      req_be <= 4'b0;
      req_we <= 1'b0;
      rdata <= 32'b0;
      init_done <= 1'b0;
      sdram_addr <= 13'b0;
      sdram_ba <= 2'b0;
      sdram_cs_n <= 1'b1;
      sdram_cke <= 1'b0;
      sdram_ras_n <= 1'b1;
      sdram_cas_n <= 1'b1;
      sdram_we_n <= 1'b1;
      sdram_dqm <= 2'b11;
      dq_out <= 16'b0;
      dq_oe <= 1'b0;
    end else begin
      dq_oe = 1'b0;
      sdram_cke = 1'b1;
      sdram_dqm = 2'b11;
      command_nop();

      if (state == STATE_IDLE && refresh_count != 16'b0) begin
        refresh_count <= refresh_count - 16'd1;
      end

      case (state)
        STATE_INIT_WAIT: begin
          if (wait_count == 16'b0) begin
            state <= STATE_INIT_PRE;
          end else begin
            wait_count <= wait_count - 16'd1;
          end
        end

        STATE_INIT_PRE: begin
          command_precharge_all();
          load_wait(TRP_CYCLES);
          state <= STATE_INIT_PRE_WAIT;
        end

        STATE_INIT_PRE_WAIT: begin
          if (wait_count == 16'b0) begin
            state <= STATE_INIT_REF1;
          end else begin
            wait_count <= wait_count - 16'd1;
          end
        end

        STATE_INIT_REF1: begin
          command_refresh();
          load_wait(REFRESH_CYCLES);
          state <= STATE_INIT_REF1_WAIT;
        end

        STATE_INIT_REF1_WAIT: begin
          if (wait_count == 16'b0) begin
            state <= STATE_INIT_REF2;
          end else begin
            wait_count <= wait_count - 16'd1;
          end
        end

        STATE_INIT_REF2: begin
          command_refresh();
          load_wait(REFRESH_CYCLES);
          state <= STATE_INIT_REF2_WAIT;
        end

        STATE_INIT_REF2_WAIT: begin
          if (wait_count == 16'b0) begin
            state <= STATE_INIT_MODE;
          end else begin
            wait_count <= wait_count - 16'd1;
          end
        end

        STATE_INIT_MODE: begin
          command_load_mode();
          load_wait(TRP_CYCLES);
          state <= STATE_INIT_MODE_WAIT;
        end

        STATE_INIT_MODE_WAIT: begin
          if (wait_count == 16'b0) begin
            init_done <= 1'b1;
            refresh_count <= REFRESH_PERIOD;
            state <= STATE_IDLE;
          end else begin
            wait_count <= wait_count - 16'd1;
          end
        end

        STATE_IDLE: begin
          if (refresh_count == 16'b0) begin
            state <= STATE_REFRESH;
          end else if (req) begin
            req_word_addr <= word_addr;
            req_wdata <= wdata;
            req_be <= be;
            req_we <= we;
            state <= STATE_ACT;
          end
        end

        STATE_REFRESH: begin
          command_refresh();
          load_wait(REFRESH_CYCLES);
          state <= STATE_REFRESH_WAIT;
        end

        STATE_REFRESH_WAIT: begin
          if (wait_count == 16'b0) begin
            refresh_count <= REFRESH_PERIOD;
            state <= STATE_IDLE;
          end else begin
            wait_count <= wait_count - 16'd1;
          end
        end

        STATE_ACT: begin
          command_activate();
          load_wait(TRCD_CYCLES);
          state <= STATE_RCD_WAIT;
        end

        STATE_RCD_WAIT: begin
          if (wait_count == 16'b0) begin
            if (req_we) begin
              state <= STATE_WRITE_LO;
            end else begin
              state <= STATE_READ_LO;
            end
          end else begin
            wait_count <= wait_count - 16'd1;
          end
        end

        STATE_READ_LO: begin
          command_read(1'b0, 1'b0);
          load_wait(CL_CYCLES);
          state <= STATE_READ_LO_WAIT;
        end

        STATE_READ_LO_WAIT: begin
          if (wait_count == 16'b0) begin
            rdata[15:0] <= sdram_dq;
            state <= STATE_READ_HI;
          end else begin
            wait_count <= wait_count - 16'd1;
          end
        end

        STATE_READ_HI: begin
          command_read(1'b1, 1'b1);
          load_wait(CL_CYCLES);
          state <= STATE_READ_HI_WAIT;
        end

        STATE_READ_HI_WAIT: begin
          if (wait_count == 16'b0) begin
            rdata[31:16] <= sdram_dq;
            state <= STATE_DONE;
          end else begin
            wait_count <= wait_count - 16'd1;
          end
        end

        STATE_WRITE_LO: begin
          command_write(1'b0, 1'b0, req_wdata[15:0], ~req_be[1:0]);
          state <= STATE_WRITE_HI;
        end

        STATE_WRITE_HI: begin
          command_write(1'b1, 1'b1, req_wdata[31:16], ~req_be[3:2]);
          load_wait(WRITE_RECOVERY_CYCLES);
          state <= STATE_WRITE_WAIT;
        end

        STATE_WRITE_WAIT: begin
          if (wait_count == 16'b0) begin
            state <= STATE_DONE;
          end else begin
            wait_count <= wait_count - 16'd1;
          end
        end

        STATE_DONE: begin
          state <= STATE_IDLE;
        end

        default: begin
          state <= STATE_INIT_WAIT;
        end
      endcase
    end
  end

endmodule
