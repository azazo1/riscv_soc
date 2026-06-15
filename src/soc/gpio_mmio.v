`timescale 1ns / 1ps

// GPIO 的 MMIO
// 地址 0x0100_0000 - 0x01ff_ffff
// 写入的时候保存 32bit 输出寄存器
// 读取的时候返回寄存器当前值
module gpio_mmio (
    input wire clk,
    input wire rst_n,
    input wire req,
    input wire we,
    input wire [3:0] be,
    input wire [31:0] addr,
    input wire [31:0] wdata,

    input wire [9:0] sw,
    input wire [3:0] key,
    input wire [35:0] gpio0_in,
    input wire [35:0] gpio1_in,

    output reg [31:0] rdata,
    output reg [ 9:0] ledr,
    output reg [ 6:0] hex0,
    output reg [ 6:0] hex1,
    output reg [ 6:0] hex2,
    output reg [ 6:0] hex3,
    output reg [ 6:0] hex4,
    output reg [ 6:0] hex5,
    output reg [35:0] gpio0_out,
    output reg [35:0] gpio0_oe,
    output reg [35:0] gpio1_out,
    output reg [35:0] gpio1_oe
);

  // 第一版, 针对 DE1-Soc 做的 GPIO 地址映射:
  // 0x0100_0000 LEDR      R/W, 低 10 bit 有效
  // 0x0100_0004 SW        R,   低 10 bit 有效
  // 0x0100_0008 KEY       R,   低 4 bit 有效
  // 0x0100_000c HEX_LOW   R/W, HEX0..HEX3, 每个 HEX 占 8 bit, 只用低 7 bit (似乎板载只支持 7 段)
  // 0x0100_0010 HEX_HIGH  R/W, HEX4..HEX5, 低 2 bytes 有效, 每个 HEX 只用低 7 bit
  // 0x0100_0020 GPIO0_IN_LOW   R,   GPIO_0[31:0]
  // 0x0100_0024 GPIO0_IN_HIGH  R,   GPIO_0[35:32]
  // 0x0100_0028 GPIO0_OUT_LOW  R/W, GPIO_0 output value [31:0]
  // 0x0100_002c GPIO0_OUT_HIGH R/W, GPIO_0 output value [35:32]
  // 0x0100_0030 GPIO0_OE_LOW   R/W, GPIO_0 output enable [31:0]
  // 0x0100_0034 GPIO0_OE_HIGH  R/W, GPIO_0 output enable [35:32]
  // 0x0100_0040 GPIO1_IN_LOW   R,   GPIO_1[31:0]
  // 0x0100_0044 GPIO1_IN_HIGH  R,   GPIO_1[35:32]
  // 0x0100_0048 GPIO1_OUT_LOW  R/W, GPIO_1 output value [31:0]
  // 0x0100_004c GPIO1_OUT_HIGH R/W, GPIO_1 output value [35:32]
  // 0x0100_0050 GPIO1_OE_LOW   R/W, GPIO_1 output enable [31:0]
  // 0x0100_0054 GPIO1_OE_HIGH  R/W, GPIO_1 output enable [35:32]

  // MMIO 字地址 (addr[7:2] 对应 32-bit word 偏移)
  localparam ADDR_LEDR = 6'b000;  // 0x0100_0000
  localparam ADDR_SW = 6'b001;  // 0x0100_0004
  localparam ADDR_KEY = 6'b010;  // 0x0100_0008
  localparam ADDR_HEX_LOW = 6'b011;  // 0x0100_000c
  localparam ADDR_HEX_HIGH = 6'b100;  // 0x0100_0010
  localparam ADDR_GPIO0_IN_LOW = 6'h08;  // 0x0100_0020
  localparam ADDR_GPIO0_IN_HIGH = 6'h09;  // 0x0100_0024
  localparam ADDR_GPIO0_OUT_LOW = 6'h0a;  // 0x0100_0028
  localparam ADDR_GPIO0_OUT_HIGH = 6'h0b;  // 0x0100_002c
  localparam ADDR_GPIO0_OE_LOW = 6'h0c;  // 0x0100_0030
  localparam ADDR_GPIO0_OE_HIGH = 6'h0d;  // 0x0100_0034
  localparam ADDR_GPIO1_IN_LOW = 6'h10;  // 0x0100_0040
  localparam ADDR_GPIO1_IN_HIGH = 6'h11;  // 0x0100_0044
  localparam ADDR_GPIO1_OUT_LOW = 6'h12;  // 0x0100_0048
  localparam ADDR_GPIO1_OUT_HIGH = 6'h13;  // 0x0100_004c
  localparam ADDR_GPIO1_OE_LOW = 6'h14;  // 0x0100_0050
  localparam ADDR_GPIO1_OE_HIGH = 6'h15;  // 0x0100_0054

  wire [15:0] addr_region = addr[23:8];
  wire [ 5:0] addr_offset = addr[7:2];

  // 读取 组合逻辑
  always @(*) begin
    if (req && !we && addr_region == 16'b0) begin
      case (addr_offset)
        ADDR_LEDR: rdata = {22'b0, ledr[9:0]};
        ADDR_SW: rdata = {22'b0, sw[9:0]};
        ADDR_KEY: rdata = {28'b0, key};
        ADDR_HEX_LOW: rdata = {1'b0, hex3, 1'b0, hex2, 1'b0, hex1, 1'b0, hex0};
        ADDR_HEX_HIGH: rdata = {16'b0, 1'b0, hex5, 1'b0, hex4};
        ADDR_GPIO0_IN_LOW: rdata = gpio0_in[31:0];
        ADDR_GPIO0_IN_HIGH: rdata = {28'b0, gpio0_in[35:32]};
        ADDR_GPIO0_OUT_LOW: rdata = gpio0_out[31:0];
        ADDR_GPIO0_OUT_HIGH: rdata = {28'b0, gpio0_out[35:32]};
        ADDR_GPIO0_OE_LOW: rdata = gpio0_oe[31:0];
        ADDR_GPIO0_OE_HIGH: rdata = {28'b0, gpio0_oe[35:32]};
        ADDR_GPIO1_IN_LOW: rdata = gpio1_in[31:0];
        ADDR_GPIO1_IN_HIGH: rdata = {28'b0, gpio1_in[35:32]};
        ADDR_GPIO1_OUT_LOW: rdata = gpio1_out[31:0];
        ADDR_GPIO1_OUT_HIGH: rdata = {28'b0, gpio1_out[35:32]};
        ADDR_GPIO1_OE_LOW: rdata = gpio1_oe[31:0];
        ADDR_GPIO1_OE_HIGH: rdata = {28'b0, gpio1_oe[35:32]};
        default: rdata = 0;
      endcase
    end else begin
      rdata = 0;
    end
  end

  // 写入 时序逻辑
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // led 高电平点亮
      ledr <= 10'h0;
      // hex (seg) 低电平点亮
      hex0 <= 7'h7f;
      hex1 <= 7'h7f;
      hex2 <= 7'h7f;
      hex3 <= 7'h7f;
      hex4 <= 7'h7f;
      hex5 <= 7'h7f;
      gpio0_out <= 36'b0;
      gpio0_oe <= 36'b0;
      gpio1_out <= 36'b0;
      gpio1_oe <= 36'b0;
    end else if (req && we && addr_region == 16'b0) begin
      case (addr_offset)
        ADDR_LEDR: begin
          if (be[0]) ledr[7:0] <= wdata[7:0];
          if (be[1]) ledr[9:8] <= wdata[9:8];
        end
        ADDR_HEX_LOW: begin
          if (be[0]) hex0 <= wdata[6:0];
          if (be[1]) hex1 <= wdata[14:8];
          if (be[2]) hex2 <= wdata[22:16];
          if (be[3]) hex3 <= wdata[30:24];
        end
        ADDR_HEX_HIGH: begin
          if (be[0]) hex4 <= wdata[6:0];
          if (be[1]) hex5 <= wdata[14:8];
        end
        ADDR_GPIO0_OUT_LOW: begin
          if (be[0]) gpio0_out[7:0] <= wdata[7:0];
          if (be[1]) gpio0_out[15:8] <= wdata[15:8];
          if (be[2]) gpio0_out[23:16] <= wdata[23:16];
          if (be[3]) gpio0_out[31:24] <= wdata[31:24];
        end
        ADDR_GPIO0_OUT_HIGH: begin
          if (be[0]) gpio0_out[35:32] <= wdata[3:0];
        end
        ADDR_GPIO0_OE_LOW: begin
          if (be[0]) gpio0_oe[7:0] <= wdata[7:0];
          if (be[1]) gpio0_oe[15:8] <= wdata[15:8];
          if (be[2]) gpio0_oe[23:16] <= wdata[23:16];
          if (be[3]) gpio0_oe[31:24] <= wdata[31:24];
        end
        ADDR_GPIO0_OE_HIGH: begin
          if (be[0]) gpio0_oe[35:32] <= wdata[3:0];
        end
        ADDR_GPIO1_OUT_LOW: begin
          if (be[0]) gpio1_out[7:0] <= wdata[7:0];
          if (be[1]) gpio1_out[15:8] <= wdata[15:8];
          if (be[2]) gpio1_out[23:16] <= wdata[23:16];
          if (be[3]) gpio1_out[31:24] <= wdata[31:24];
        end
        ADDR_GPIO1_OUT_HIGH: begin
          if (be[0]) gpio1_out[35:32] <= wdata[3:0];
        end
        ADDR_GPIO1_OE_LOW: begin
          if (be[0]) gpio1_oe[7:0] <= wdata[7:0];
          if (be[1]) gpio1_oe[15:8] <= wdata[15:8];
          if (be[2]) gpio1_oe[23:16] <= wdata[23:16];
          if (be[3]) gpio1_oe[31:24] <= wdata[31:24];
        end
        ADDR_GPIO1_OE_HIGH: begin
          if (be[0]) gpio1_oe[35:32] <= wdata[3:0];
        end
        default: ;
      endcase
    end  // if (req && we)
  end

endmodule
