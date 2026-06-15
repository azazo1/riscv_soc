`timescale 1ns / 1ps

// 简单 SPI master MMIO, SPI mode 0, 8-bit, MSB first.
// 0x0100_0200 SPI_TXDATA, 写低 8 bit 启动一次传输
// 0x0100_0204 SPI_RXDATA, 读低 8 bit 获取最近一次接收数据
// 0x0100_0208 SPI_STATUS, bit0=ready, bit1=busy
// 0x0100_020c SPI_CTRL, bit0=cs_n
// 0x0100_0210 SPI_DIV, SCLK 半周期分频, 最小值为 1
module spi_master_mmio (
    input wire clk,
    input wire rst_n,
    input wire req,
    input wire we,
    input wire [3:0] be,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output reg [31:0] rdata,

    input wire spi_miso,
    output wire spi_sclk,
    output wire spi_mosi,
    output wire spi_cs_n
);

  localparam ADDR_TXDATA = 6'h00;  // 0x0100_0200
  localparam ADDR_RXDATA = 6'h01;  // 0x0100_0204
  localparam ADDR_STATUS = 6'h02;  // 0x0100_0208
  localparam ADDR_CTRL = 6'h03;  // 0x0100_020c
  localparam ADDR_DIV = 6'h04;  // 0x0100_0210

  localparam STATE_IDLE = 1'b0;
  localparam STATE_BUSY = 1'b1;

  reg state;
  reg sclk_reg;
  reg mosi_reg;
  reg cs_n_reg;
  reg [7:0] tx_shift;
  reg [7:0] rx_shift;
  reg [7:0] rx_data;
  reg [2:0] bit_index;
  reg [15:0] div_reg;
  reg [15:0] div_count;

  wire addr_hit = (addr[31:8] == 24'h010002);
  wire [5:0] addr_offset = addr[7:2];
  wire ready = (state == STATE_IDLE);
  wire busy = (state == STATE_BUSY);

  assign spi_sclk = sclk_reg;
  assign spi_mosi = mosi_reg;
  assign spi_cs_n = cs_n_reg;

  always @(*) begin
    if (req && !we && addr_hit) begin
      case (addr_offset)
        ADDR_TXDATA: rdata = {24'b0, tx_shift};
        ADDR_RXDATA: rdata = {24'b0, rx_data};
        ADDR_STATUS: rdata = {30'b0, busy, ready};
        ADDR_CTRL:   rdata = {31'b0, cs_n_reg};
        ADDR_DIV:    rdata = {16'b0, div_reg};
        default:     rdata = 32'b0;
      endcase
    end else begin
      rdata = 32'b0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      sclk_reg <= 1'b0;
      mosi_reg <= 1'b1;
      cs_n_reg <= 1'b1;
      tx_shift <= 8'hff;
      rx_shift <= 8'b0;
      rx_data <= 8'b0;
      bit_index <= 3'b0;
      div_reg <= 16'd2;
      div_count <= 16'b0;
    end else begin
      if (req && we && addr_hit && be[0]) begin
        case (addr_offset)
          ADDR_CTRL: begin
            cs_n_reg <= wdata[0];
          end

          ADDR_DIV: begin
            if (wdata[15:0] == 16'b0) begin
              div_reg <= 16'd1;
            end else begin
              div_reg <= wdata[15:0];
            end
          end

          ADDR_TXDATA: begin
            if (ready) begin
              state <= STATE_BUSY;
              sclk_reg <= 1'b0;
              tx_shift <= wdata[7:0];
              rx_shift <= 8'b0;
              bit_index <= 3'd7;
              div_count <= 16'b0;
              mosi_reg <= wdata[7];
            end
          end

          default: begin
          end
        endcase
      end

      if (busy) begin
        if (div_count == div_reg - 16'd1) begin
          div_count <= 16'b0;

          if (sclk_reg == 1'b0) begin
            sclk_reg <= 1'b1;
            rx_shift[bit_index] <= spi_miso;
          end else begin
            sclk_reg <= 1'b0;
            if (bit_index == 3'b0) begin
              state <= STATE_IDLE;
              rx_data <= rx_shift;
              rx_data[0] <= spi_miso;
              mosi_reg <= 1'b1;
            end else begin
              bit_index <= bit_index - 3'd1;
              mosi_reg <= tx_shift[bit_index-3'd1];
            end
          end
        end else begin
          div_count <= div_count + 16'd1;
        end
      end
    end
  end

endmodule
