`timescale 1ns / 1ps

// 适用于 de1_soc 的顶层模块, 用于在 quartus 中直接编译.
module de1_soc_top #(
    parameter ROM_FILE = "firmware/c_demo/c_demo.hex"
) (
    input wire clk,

    input  wire [9:0] sw,
    input  wire [3:0] key,
    output wire [9:0] ledr,
    output wire [6:0] hex0,
    output wire [6:0] hex1,
    output wire [6:0] hex2,
    output wire [6:0] hex3,
    output wire [6:0] hex4,
    output wire [6:0] hex5,

    inout wire [35:0] gpio0,
    // 实机上, gpio1[0] 位于右侧 40 针脚中的最左上的针脚.
    inout wire [35:0] gpio1
);

  wire [35:0] gpio0_out;
  wire [35:0] gpio0_oe;
  wire [35:0] gpio1_out;
  wire [35:0] gpio1_oe;
  wire uart_tx_pin;

  genvar i;
  generate
    for (i = 0; i < 36; i = i + 1) begin : gen_gpio0
      assign gpio0[i] = gpio0_oe[i] ? gpio0_out[i] : 1'bz;
    end

    for (i = 1; i < 36; i = i + 1) begin : gen_gpio1
      assign gpio1[i] = gpio1_oe[i] ? gpio1_out[i] : 1'bz;
    end
  endgenerate

  // GPIO_1[0] 暂时作为 UART TX 使用, 接到 USB-TTL 的 RX.
  assign gpio1[0] = uart_tx_pin;

  rv32i_soc #(
      .ROM_FILE(ROM_FILE)
  ) u_soc (
      .clk(clk),
      .rst_n(~sw[9]),  // 使用 SW9 作为板级复位, SW9=1 时内部 rst_n=0.
      .sw(sw),
      .key(key),
      .ledr(ledr),
      .hex0(hex0),
      .hex1(hex1),
      .hex2(hex2),
      .hex3(hex3),
      .hex4(hex4),
      .hex5(hex5),
      .gpio0_in(gpio0),
      .gpio1_in(gpio1),
      .gpio0_out(gpio0_out),
      .gpio0_oe(gpio0_oe),
      .gpio1_out(gpio1_out),
      .gpio1_oe(gpio1_oe),
      .uart_tx_pin(uart_tx_pin)
  );

endmodule
