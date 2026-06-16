`timescale 1ns / 1ps

// 片上双口 RAM 适配层.
// data 口给 data bus 使用, 支持 byte enable 写入.
// imem 口给 CPU 取指使用, 只读.
// Quartus 打开 USE_ONCHIP_RAM_IP 时实例化 onchip_ram IP, 仿真时使用行为模型.
module onchip_dual_port_ram #(
    parameter RAM_WORD_ADDR_BITS = 10
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

    input wire imem_req,
    input wire [31:0] imem_addr,
    output wire [31:0] imem_rdata,
    output wire imem_ready
);

  localparam DATA_IDLE = 1'b0;
  localparam DATA_RESP = 1'b1;

  localparam IMEM_IDLE = 2'd0;
  localparam IMEM_WAIT = 2'd1;
  localparam IMEM_RESP = 2'd2;

  reg data_state;
  reg [1:0] imem_state;
  reg [RAM_WORD_ADDR_BITS-1:0] imem_word_addr_q;

  wire [RAM_WORD_ADDR_BITS-1:0] word_addr = addr[RAM_WORD_ADDR_BITS+1:2];
  wire [RAM_WORD_ADDR_BITS-1:0] imem_word_addr = imem_addr[RAM_WORD_ADDR_BITS+1:2];
  wire imem_hit = imem_state == IMEM_RESP && imem_word_addr_q == imem_word_addr;

  assign ready = data_state == DATA_RESP;
  assign imem_ready = !imem_req || imem_hit;
  assign rdata = ready ? ram_q_a : 32'b0;
  assign imem_rdata = imem_hit ? ram_q_b : 32'h0000_0013;

`ifdef USE_ONCHIP_RAM_IP
  wire [31:0] ram_q_a;
  wire [31:0] ram_q_b;

  onchip_ram u_onchip_ram (
      .address_a(word_addr),
      .address_b(imem_word_addr),
      .byteena_a(be),
      .clock(clk),
      .data_a(wdata),
      .data_b(32'b0),
      .wren_a(req && we && data_state == DATA_IDLE),
      .wren_b(1'b0),
      .q_a(ram_q_a),
      .q_b(ram_q_b)
  );
`else
  localparam RAM_WORDS = 1 << RAM_WORD_ADDR_BITS;

  (* ramstyle = "M10K" *) reg [31:0] ram_data[0:RAM_WORDS-1];
  reg [31:0] ram_q_a;
  reg [31:0] ram_q_b;
  reg [RAM_WORD_ADDR_BITS-1:0] ram_addr_b_q;

  always @(posedge clk) begin
    if (req && data_state == DATA_IDLE) begin
      ram_q_a <= ram_data[word_addr];
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
    end

    if (imem_req && !imem_hit) begin
      ram_addr_b_q <= imem_word_addr;
    end

    ram_q_b <= ram_data[ram_addr_b_q];
  end
`endif

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_state <= DATA_IDLE;
    end else begin
      case (data_state)
        DATA_IDLE: begin
          if (req) begin
            data_state <= DATA_RESP;
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
      imem_state <= IMEM_IDLE;
      imem_word_addr_q <= {RAM_WORD_ADDR_BITS{1'b0}};
    end else begin
      case (imem_state)
        IMEM_IDLE: begin
          if (imem_req) begin
            imem_word_addr_q <= imem_word_addr;
            imem_state <= IMEM_WAIT;
          end
        end
        IMEM_WAIT: begin
          imem_state <= IMEM_RESP;
        end
        IMEM_RESP: begin
          if (!imem_req) begin
            imem_state <= IMEM_IDLE;
          end else if (!imem_hit) begin
            imem_word_addr_q <= imem_word_addr;
            imem_state <= IMEM_WAIT;
          end
        end
        default: begin
          imem_state <= IMEM_IDLE;
        end
      endcase
    end
  end

endmodule
