`timescale 1ns / 1ps

module simple_bus_vlg_tst;
  reg clk;
  reg req;
  reg we;
  reg [3:0] be;
  reg [31:0] addr;
  reg [31:0] wdata;
  wire [31:0] rdata;
  wire ready;

  wire rom_req;
  wire [31:0] rom_addr;
  reg [31:0] rom_rdata;

  wire ram_req;
  wire ram_we;
  wire [3:0] ram_be;
  wire [31:0] ram_addr;
  wire [31:0] ram_wdata;
  reg [31:0] ram_rdata;
  reg ram_ready;

  wire gpio_req;
  wire gpio_we;
  wire [3:0] gpio_be;
  wire [31:0] gpio_addr;
  wire [31:0] gpio_wdata;
  reg [31:0] gpio_rdata;

  wire uart_req;
  wire uart_we;
  wire [3:0] uart_be;
  wire [31:0] uart_addr;
  wire [31:0] uart_wdata;
  reg [31:0] uart_rdata;

  wire spi_req;
  wire spi_we;
  wire [3:0] spi_be;
  wire [31:0] spi_addr;
  wire [31:0] spi_wdata;
  reg [31:0] spi_rdata;

  wire sdram_req;
  wire sdram_we;
  wire [3:0] sdram_be;
  wire [31:0] sdram_addr;
  wire [31:0] sdram_wdata;
  reg [31:0] sdram_rdata;
  reg sdram_ready;

  localparam RAM_BASE = 32'h0000_8000;
  localparam SDRAM_BASE = 32'h0200_0000;

  simple_bus dut (
      .clk(clk),
      .req(req),
      .we(we),
      .be(be),
      .addr(addr),
      .wdata(wdata),
      .rdata(rdata),
      .ready(ready),
      .rom_req(rom_req),
      .rom_addr(rom_addr),
      .rom_rdata(rom_rdata),
      .ram_req(ram_req),
      .ram_we(ram_we),
      .ram_be(ram_be),
      .ram_addr(ram_addr),
      .ram_wdata(ram_wdata),
      .ram_rdata(ram_rdata),
      .ram_ready(ram_ready),
      .gpio_req(gpio_req),
      .gpio_we(gpio_we),
      .gpio_be(gpio_be),
      .gpio_addr(gpio_addr),
      .gpio_wdata(gpio_wdata),
      .gpio_rdata(gpio_rdata),
      .uart_req(uart_req),
      .uart_we(uart_we),
      .uart_be(uart_be),
      .uart_addr(uart_addr),
      .uart_wdata(uart_wdata),
      .uart_rdata(uart_rdata),
      .spi_req(spi_req),
      .spi_we(spi_we),
      .spi_be(spi_be),
      .spi_addr(spi_addr),
      .spi_wdata(spi_wdata),
      .spi_rdata(spi_rdata),
      .sdram_req(sdram_req),
      .sdram_we(sdram_we),
      .sdram_be(sdram_be),
      .sdram_addr(sdram_addr),
      .sdram_wdata(sdram_wdata),
      .sdram_rdata(sdram_rdata),
      .sdram_ready(sdram_ready)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task expect_rom_hit;
    input [31:0] test_addr;
    input [31:0] test_rom_rdata;
    input [31:0] check_id;
    begin
      req = 1'b1;
      we = 1'b0;
      be = 4'b1111;
      addr = test_addr;
      wdata = 32'h0000_0000;
      rom_rdata = test_rom_rdata;
      #1;

      if (rom_req !== 1'b1 || ram_req !== 1'b0 || gpio_req !== 1'b0 || uart_req !== 1'b0 || spi_req !== 1'b0 ||
          sdram_req !== 1'b0 || rom_addr !== test_addr || rdata !== test_rom_rdata || ready !== 1'b1) begin
        $display("check %0d rom hit failed", check_id);
        $display("rom_req=%b rom_addr=%h rdata=%h", rom_req, rom_addr, rdata);
        $fatal;
      end
    end
  endtask

  task expect_ram_hit;
    input test_we;
    input [3:0] test_be;
    input [31:0] test_addr;
    input [31:0] test_wdata;
    input [31:0] test_ram_rdata;
    input test_ram_ready;
    input [31:0] check_id;
    begin
      req = 1'b1;
      we = test_we;
      be = test_be;
      addr = test_addr;
      wdata = test_wdata;
      ram_rdata = test_ram_rdata;
      ram_ready = test_ram_ready;
      #1;

      if (rom_req !== 1'b0 || ram_req !== 1'b1 || gpio_req !== 1'b0 || uart_req !== 1'b0 || spi_req !== 1'b0 ||
          sdram_req !== 1'b0 ||
          ram_we !== test_we || ram_be !== test_be ||
          ram_addr !== (test_addr - RAM_BASE) || ram_wdata !== test_wdata || rdata !== test_ram_rdata || ready !== test_ram_ready) begin
        $display("check %0d ram hit failed", check_id);
        $display("ram_req=%b ram_we=%b ram_be=%b ram_addr=%h ram_wdata=%h rdata=%h",
                 ram_req, ram_we, ram_be, ram_addr, ram_wdata, rdata);
        $fatal;
      end
    end
  endtask

  task expect_gpio_hit;
    input test_we;
    input [3:0] test_be;
    input [31:0] test_addr;
    input [31:0] test_wdata;
    input [31:0] test_gpio_rdata;
    input [31:0] check_id;
    begin
      req = 1'b1;
      we = test_we;
      be = test_be;
      addr = test_addr;
      wdata = test_wdata;
      gpio_rdata = test_gpio_rdata;
      #1;

      if (rom_req !== 1'b0 || ram_req !== 1'b0 || gpio_req !== 1'b1 || uart_req !== 1'b0 || spi_req !== 1'b0 ||
          sdram_req !== 1'b0 ||
          gpio_we !== test_we ||
          gpio_be !== test_be || gpio_addr !== test_addr ||
          gpio_wdata !== test_wdata || rdata !== test_gpio_rdata || ready !== 1'b1) begin
        $display("check %0d gpio hit failed", check_id);
        $display("ram_req=%b gpio_req=%b gpio_we=%b gpio_be=%b gpio_addr=%h gpio_wdata=%h rdata=%h",
                 ram_req, gpio_req, gpio_we, gpio_be, gpio_addr, gpio_wdata, rdata);
        $fatal;
      end
    end
  endtask

  task expect_uart_hit;
    input test_we;
    input [3:0] test_be;
    input [31:0] test_addr;
    input [31:0] test_wdata;
    input [31:0] test_uart_rdata;
    input [31:0] check_id;
    begin
      req = 1'b1;
      we = test_we;
      be = test_be;
      addr = test_addr;
      wdata = test_wdata;
      uart_rdata = test_uart_rdata;
      #1;

      if (rom_req !== 1'b0 || ram_req !== 1'b0 || gpio_req !== 1'b0 || uart_req !== 1'b1 || spi_req !== 1'b0 ||
          sdram_req !== 1'b0 ||
          uart_we !== test_we || uart_be !== test_be ||
          uart_addr !== test_addr || uart_wdata !== test_wdata ||
          rdata !== test_uart_rdata || ready !== 1'b1) begin
        $display("check %0d uart hit failed", check_id);
        $display("ram_req=%b gpio_req=%b uart_req=%b uart_we=%b uart_be=%b uart_addr=%h uart_wdata=%h rdata=%h",
                 ram_req, gpio_req, uart_req, uart_we, uart_be, uart_addr, uart_wdata, rdata);
        $fatal;
      end
    end
  endtask

  task expect_spi_hit;
    input test_we;
    input [3:0] test_be;
    input [31:0] test_addr;
    input [31:0] test_wdata;
    input [31:0] test_spi_rdata;
    input [31:0] check_id;
    begin
      req = 1'b1;
      we = test_we;
      be = test_be;
      addr = test_addr;
      wdata = test_wdata;
      spi_rdata = test_spi_rdata;
      #1;

      if (rom_req !== 1'b0 || ram_req !== 1'b0 || gpio_req !== 1'b0 || uart_req !== 1'b0 || spi_req !== 1'b1 ||
          sdram_req !== 1'b0 ||
          spi_we !== test_we || spi_be !== test_be ||
          spi_addr !== test_addr || spi_wdata !== test_wdata ||
          rdata !== test_spi_rdata || ready !== 1'b1) begin
        $display("check %0d spi hit failed", check_id);
        $display("spi_req=%b spi_we=%b spi_be=%b spi_addr=%h spi_wdata=%h rdata=%h",
                 spi_req, spi_we, spi_be, spi_addr, spi_wdata, rdata);
        $fatal;
      end
    end
  endtask

  task expect_sdram_hit;
    input test_we;
    input [3:0] test_be;
    input [31:0] test_addr;
    input [31:0] test_wdata;
    input [31:0] test_sdram_rdata;
    input test_sdram_ready;
    input [31:0] check_id;
    begin
      req = 1'b1;
      we = test_we;
      be = test_be;
      addr = test_addr;
      wdata = test_wdata;
      sdram_rdata = test_sdram_rdata;
      sdram_ready = test_sdram_ready;
      #1;

      if (rom_req !== 1'b0 || ram_req !== 1'b0 || gpio_req !== 1'b0 || uart_req !== 1'b0 || spi_req !== 1'b0 ||
          sdram_req !== 1'b1 || sdram_we !== test_we || sdram_be !== test_be ||
          sdram_addr !== (test_addr - SDRAM_BASE) || sdram_wdata !== test_wdata ||
          rdata !== test_sdram_rdata || ready !== test_sdram_ready) begin
        $display("check %0d sdram hit failed", check_id);
        $display("sdram_req=%b sdram_we=%b sdram_be=%b sdram_addr=%h sdram_wdata=%h rdata=%h ready=%b",
                 sdram_req, sdram_we, sdram_be, sdram_addr, sdram_wdata, rdata, ready);
        $fatal;
      end
    end
  endtask

  task expect_ram_miss;
    input [31:0] test_addr;
    input [31:0] check_id;
    begin
      req = 1'b1;
      we = 1'b1;
      be = 4'b1111;
      addr = test_addr;
      wdata = 32'h5566_7788;
      ram_rdata = 32'haabb_ccdd;
      gpio_rdata = 32'h1122_3344;
      uart_rdata = 32'h5566_aabb;
      spi_rdata = 32'h7788_99aa;
      #1;

      if (rom_req !== 1'b0 || ram_req !== 1'b0 || gpio_req !== 1'b0 || uart_req !== 1'b0 || spi_req !== 1'b0 ||
          sdram_req !== 1'b0 || rdata !== 32'b0 || ready !== 1'b1) begin
        $display("check %0d miss failed: rom_req=%b ram_req=%b gpio_req=%b uart_req=%b spi_req=%b sdram_req=%b rdata=%h ready=%b", check_id, rom_req, ram_req, gpio_req, uart_req, spi_req, sdram_req, rdata, ready);
        $fatal;
      end
    end
  endtask

  initial begin
    req = 1'b0;
    we = 1'b0;
    be = 4'b0000;
    addr = 32'b0;
    wdata = 32'b0;
    rom_rdata = 32'b0;
    ram_rdata = 32'b0;
    ram_ready = 1'b1;
    gpio_rdata = 32'b0;
    uart_rdata = 32'b0;
    spi_rdata = 32'b0;
    sdram_rdata = 32'b0;
    sdram_ready = 1'b1;

    #1;

    expect_rom_hit(32'h0000_0000, 32'h1122_3344, 32'd1);
    expect_rom_hit(32'h0000_7ffc, 32'haabb_ccdd, 32'd2);
    expect_ram_miss(32'h0000_0000, 32'd3);
    expect_ram_hit(1'b0, 4'b1111, 32'h0000_8000, 32'h0000_0000, 32'h1122_3344, 1'b0, 32'd4);
    expect_ram_hit(1'b1, 4'b0101, 32'h0000_800c, 32'h5566_7788, 32'h99aa_bbcc, 1'b1, 32'd5);
    expect_ram_hit(1'b0, 4'b1111, 32'h0000_8400, 32'h0000_0000, 32'h1234_abcd, 1'b1, 32'd6);
    expect_ram_hit(1'b0, 4'b1111, 32'h0000_fffc, 32'h0000_0000, 32'hdead_beef, 1'b1, 32'd7);
    expect_ram_miss(32'h0001_0000, 32'd8);

    expect_gpio_hit(1'b0, 4'b1111, 32'h0100_0000, 32'h0000_0000, 32'h1357_2468, 32'd9);
    expect_gpio_hit(1'b1, 4'b0011, 32'h0100_0010, 32'h0000_03ff, 32'h2468_1357, 32'd10);

    expect_gpio_hit(1'b0, 4'b1111, 32'h0100_00fc, 32'h0000_0000, 32'h0100_00fc, 32'd11);
    expect_uart_hit(1'b1, 4'b1111, 32'h0100_0100, 32'h5566_7788, 32'h0000_0003, 32'd12);
    expect_uart_hit(1'b0, 4'b1111, 32'h0100_0104, 32'h0000_0000, 32'h0000_0001, 32'd13);

    expect_spi_hit(1'b1, 4'b0001, 32'h0100_0200, 32'h0000_00a5, 32'h0000_0002, 32'd14);
    expect_sdram_hit(1'b1, 4'b1111, 32'h0200_0000, 32'h1122_3344, 32'haabb_ccdd, 1'b0, 32'd15);
    expect_sdram_hit(1'b0, 4'b1111, 32'h0200_0004, 32'h0000_0000, 32'h5566_7788, 1'b1, 32'd16);
    expect_sdram_hit(1'b0, 4'b1111, 32'h05ff_fffc, 32'h0000_0000, 32'h99aa_bbcc, 1'b1, 32'd17);
    expect_ram_miss(32'h0600_0000, 32'd18);

    req = 1'b0;
    we = 1'b1;
    be = 4'b1111;
    addr = 32'h0000_0000;
    wdata = 32'h1234_5678;
    ram_rdata = 32'h8765_4321;
    gpio_rdata = 32'h1122_3344;
    uart_rdata = 32'h5566_aabb;
    spi_rdata = 32'h7788_99aa;
    #1;
    if (rom_req !== 1'b0 || ram_req !== 1'b0 || gpio_req !== 1'b0 || uart_req !== 1'b0 || spi_req !== 1'b0 ||
        sdram_req !== 1'b0 || rdata !== 32'b0 || ready !== 1'b1) begin
      $display("idle request should not access ram");
      $fatal;
    end

    $display("simple_bus test passed");
    $finish;
  end
endmodule
