`timescale 1ns / 1ps

// 断言 bootloader jump 之前不能访问 sdram.
module rv32i_soc_bootloader_stack_vlg_tst;
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
  wire spi_miso;
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

  localparam BOOT_RAM_BASE = 32'h0000_f000;
  localparam BOOT_RAM_LIMIT = 32'h0001_0000;
  localparam BOOT_STACK_LOW = 32'h0000_ff00;
  localparam SDRAM_BASE = 32'h0200_0000;
  localparam SDRAM_LIMIT = 32'h0600_0000;

  reg [2:0] spi_bit_index;
  reg [7:0] spi_byte_index;
  reg stack_load_seen;

  wire [7:0] spi_response_byte =
      spi_cs_n ? 8'hff :
      (spi_byte_index == 8'd6) ? 8'h01 : 8'hff;

  assign spi_miso = spi_response_byte[3'd7-spi_bit_index];

  rv32i_soc #(
      .RESET_PC(32'h0000_0000),
      .ROM_FILE("firmware/bootloader/bootloader.hex"),
      .UART_CLKS_PER_BIT(2)
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
      .spi_miso(spi_miso),
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

  always @(posedge spi_sclk or posedge spi_cs_n or negedge rst_n) begin
    if (!rst_n || spi_cs_n) begin
      spi_bit_index <= 3'b0;
      spi_byte_index <= 8'b0;
    end else if (spi_bit_index == 3'd7) begin
      spi_bit_index <= 3'b0;
      spi_byte_index <= spi_byte_index + 8'd1;
    end else begin
      spi_bit_index <= spi_bit_index + 3'd1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stack_load_seen <= 1'b0;
    end else begin
      if (dut.dmem_req && !dut.dmem_we &&
          dut.dmem_addr >= BOOT_STACK_LOW && dut.dmem_addr < BOOT_RAM_LIMIT) begin
        stack_load_seen <= 1'b1;
      end

      if (dut.dmem_req && !dut.dmem_we &&
          dut.dmem_addr >= SDRAM_BASE && dut.dmem_addr < SDRAM_LIMIT) begin
        $display("bootloader read sdram before app jump: addr=%h", dut.dmem_addr);
        $fatal;
      end

      if (dut.imem_sdram_req) begin
        $display("bootloader fetched from sdram before app jump");
        $fatal;
      end

      if (dut.u_core.u_regfile.regs[2] != 32'b0 &&
          (dut.u_core.u_regfile.regs[2] < BOOT_RAM_BASE ||
           dut.u_core.u_regfile.regs[2] > BOOT_RAM_LIMIT)) begin
        $display("bootloader sp out of boot ram: sp=%h", dut.u_core.u_regfile.regs[2]);
        $fatal;
      end
    end
  end

  initial begin
    integer wait_count;

    rst_n = 1'b1;
    sw = 10'h000;
    key = 4'b1111;
    gpio0_in = 36'h0;
    gpio1_in = 36'h0;
    spi_bit_index = 3'b0;
    spi_byte_index = 8'b0;
    stack_load_seen = 1'b0;

    #1;
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    wait_count = 0;
    while (!stack_load_seen && wait_count < 200000) begin
      wait_count = wait_count + 1;
      @(posedge clk);
    end
    #1;

    if (!stack_load_seen) begin
      $display("bootloader stack load was not observed");
      $fatal;
    end

    $display("rv32i_soc_bootloader_stack test passed");
    $finish;
  end
endmodule
