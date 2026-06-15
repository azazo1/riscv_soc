`timescale 1ns / 1ps

module rv32i_soc_ram_exec_vlg_tst;
  reg clk;
  reg rst_n;
  reg [9:0] sw;
  reg [3:0] key;
  wire [9:0] ledr;
  wire [6:0] hex0;
  wire [6:0] hex1;
  wire [6:0] hex2;
  wire [6:0] hex3;
  wire [6:0] hex4;
  wire [6:0] hex5;
  reg [35:0] gpio0_in;
  reg [35:0] gpio1_in;
  wire [35:0] gpio0_out;
  wire [35:0] gpio0_oe;
  wire [35:0] gpio1_out;
  wire [35:0] gpio1_oe;
  wire uart_tx_pin;
  wire spi_sclk;
  wire spi_mosi;
  wire spi_cs_n;
  wire [7:0] vga_r;
  wire [7:0] vga_g;
  wire [7:0] vga_b;
  wire vga_hs;
  wire vga_vs;
  wire vga_blank_n;
  wire vga_sync_n;
  wire vga_clk;
  wire [12:0] sdram_addr;
  wire [1:0] sdram_ba;
  wire sdram_cas_n;
  wire sdram_cke;
  wire sdram_clk;
  wire sdram_cs_n;
  wire [15:0] sdram_dq;
  wire sdram_ldqm;
  wire sdram_ras_n;
  wire sdram_udqm;
  wire sdram_we_n;

  localparam OPCODE_LUI = 7'b0110111;
  localparam OPCODE_OP_IMM = 7'b0010011;
  localparam OPCODE_STORE = 7'b0100011;
  localparam OPCODE_BRANCH = 7'b1100011;

  rv32i_soc #(
      .RESET_PC(32'h0000_8000),
      .ROM_FILE("firmware/test/simple_rom.hex")
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .sw(sw),
      .key(key),
      .ledr(ledr),
      .hex0(hex0),
      .hex1(hex1),
      .hex2(hex2),
      .hex3(hex3),
      .hex4(hex4),
      .hex5(hex5),
      .gpio0_in(gpio0_in),
      .gpio1_in(gpio1_in),
      .gpio0_out(gpio0_out),
      .gpio0_oe(gpio0_oe),
      .gpio1_out(gpio1_out),
      .gpio1_oe(gpio1_oe),
      .uart_tx_pin(uart_tx_pin),
      .spi_miso(1'b1),
      .spi_sclk(spi_sclk),
      .spi_mosi(spi_mosi),
      .spi_cs_n(spi_cs_n),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .vga_hs(vga_hs),
      .vga_vs(vga_vs),
      .vga_blank_n(vga_blank_n),
      .vga_sync_n(vga_sync_n),
      .vga_clk(vga_clk),
      .sdram_addr(sdram_addr),
      .sdram_ba(sdram_ba),
      .sdram_cas_n(sdram_cas_n),
      .sdram_cke(sdram_cke),
      .sdram_clk(sdram_clk),
      .sdram_cs_n(sdram_cs_n),
      .sdram_dq(sdram_dq),
      .sdram_ldqm(sdram_ldqm),
      .sdram_ras_n(sdram_ras_n),
      .sdram_udqm(sdram_udqm),
      .sdram_we_n(sdram_we_n)
  );

  sdram_model u_sdram_model (
      .clk(sdram_clk),
      .sdram_addr(sdram_addr),
      .sdram_ba(sdram_ba),
      .sdram_cs_n(sdram_cs_n),
      .sdram_cke(sdram_cke),
      .sdram_ras_n(sdram_ras_n),
      .sdram_cas_n(sdram_cas_n),
      .sdram_we_n(sdram_we_n),
      .sdram_dqm({sdram_udqm, sdram_ldqm}),
      .sdram_dq(sdram_dq)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function [31:0] instr_i;
    input [11:0] imm;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    input [6:0] opcode;
    begin
      instr_i = {imm, rs1, funct3, rd, opcode};
    end
  endfunction

  function [31:0] instr_s;
    input [11:0] imm;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    begin
      instr_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], OPCODE_STORE};
    end
  endfunction

  function [31:0] instr_b;
    input [12:0] imm;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    begin
      instr_b = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], OPCODE_BRANCH};
    end
  endfunction

  function [31:0] instr_u;
    input [19:0] imm20;
    input [4:0] rd;
    input [6:0] opcode;
    begin
      instr_u = {imm20, rd, opcode};
    end
  endfunction

  task expect_value;
    input [31:0] actual;
    input [31:0] expected;
    input [31:0] check_id;
    begin
      if (actual !== expected) begin
        $display("check %0d failed: expected %h, got %h", check_id, expected, actual);
        $fatal;
      end
    end
  endtask

  initial begin
    rst_n = 1'b1;
    sw = 10'h000;
    key = 4'b1111;
    gpio0_in = 36'h0;
    gpio1_in = 36'h0;

    // RAM 本地 word 0 对应 CPU 地址 0x0000_8000.
    dut.u_ram.ram_data[0] = instr_u(20'h01000, 5'd1, OPCODE_LUI);
    dut.u_ram.ram_data[1] = instr_i(12'h12a, 5'd0, 3'b000, 5'd2, OPCODE_OP_IMM);
    dut.u_ram.ram_data[2] = instr_s(12'd0, 5'd2, 5'd1, 3'b010);
    dut.u_ram.ram_data[3] = instr_b(13'd0, 5'd0, 5'd0, 3'b000);

    #1;
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    repeat (16) @(posedge clk);
    #1;

    expect_value({22'b0, ledr}, 32'h0000_012a, 32'd1);
    expect_value(dut.u_core.u_pc_reg.pc, 32'h0000_800c, 32'd2);

    $display("rv32i_soc_ram_exec test passed");
    $finish;
  end
endmodule
