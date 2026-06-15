`timescale 1ns / 1ps

// 简单双读口 RAM.
// data 口给 data bus 使用, 支持同步读写.
// imem 口只读, 给 CPU 从 RAM 取指使用.
// RAM 内容不要在 reset 中清零, 这样 Quartus 更容易推断为 M10K.
module simple_dual_port_ram #(
    parameter RAM_WORDS = 8192,
    parameter RAM_WORD_ADDR_BITS = 13
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

    input wire imem_req,
    input wire [31:0] imem_addr,
    output reg [31:0] imem_rdata,
    output wire imem_ready
);

  (* ramstyle = "M10K" *) reg [31:0] ram_data[0:RAM_WORDS-1];

  wire [RAM_WORD_ADDR_BITS-1:0] word_addr = addr[RAM_WORD_ADDR_BITS+1:2];
  wire [RAM_WORD_ADDR_BITS-1:0] imem_word_addr = imem_addr[RAM_WORD_ADDR_BITS+1:2];

  localparam DATA_IDLE = 1'b0;
  localparam DATA_RESP = 1'b1;

  reg data_state;
  reg imem_valid;
  reg [RAM_WORD_ADDR_BITS-1:0] imem_word_addr_q;

  wire imem_hit = imem_valid && imem_word_addr_q == imem_word_addr;

  assign ready = data_state == DATA_RESP;
  assign imem_ready = !imem_req || imem_hit;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rdata <= 32'b0;
      data_state <= DATA_IDLE;
    end else begin
      case (data_state)
        DATA_IDLE: begin
          if (req) begin
            rdata <= ram_data[word_addr];
            data_state <= DATA_RESP;
            if (we) begin
              if (be[0]) begin
                ram_data[word_addr][7:0] <= wdata[7:0];
              end
              if (be[1]) begin
                ram_data[word_addr][15:8] <= wdata[15:8];
              end
              if (be[2]) begin
                ram_data[word_addr][23:16] <= wdata[23:16];
              end
              if (be[3]) begin
                ram_data[word_addr][31:24] <= wdata[31:24];
              end
            end
          end else begin
            rdata <= 32'b0;
          end
        end
        DATA_RESP: begin
          data_state <= DATA_IDLE;
        end
        default: begin
          data_state <= DATA_IDLE;
        end
      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      imem_rdata <= 32'h0000_0013;
      imem_valid <= 1'b0;
      imem_word_addr_q <= {RAM_WORD_ADDR_BITS{1'b0}};
    end else begin
      if (imem_req && !imem_hit) begin
        imem_rdata <= ram_data[imem_word_addr];
        imem_word_addr_q <= imem_word_addr;
        imem_valid <= 1'b1;
      end else if (!imem_req) begin
        imem_rdata <= 32'h0000_0013;
        imem_valid <= 1'b0;
      end
    end
  end

endmodule
