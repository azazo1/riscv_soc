`timescale 1ns / 1ps

module load_store_unit_vlg_tst;

  reg [2:0] funct3;
  reg [1:0] addr_low;
  reg [31:0] rs2_data;
  reg [31:0] load_rdata;
  wire [3:0] store_be;
  wire [31:0] store_wdata;
  wire store_misaligned;
  wire [31:0] load_data;
  wire load_misaligned;

  localparam LS_B = 3'b000;
  localparam LS_H = 3'b001;
  localparam LS_W = 3'b010;
  localparam LD_LBU = 3'b100;
  localparam LD_LHU = 3'b101;

  load_store_unit dut (
      .funct3(funct3),
      .addr_low(addr_low),
      .rs2_data(rs2_data),
      .load_rdata(load_rdata),
      .store_be(store_be),
      .store_wdata(store_wdata),
      .store_misaligned(store_misaligned),
      .load_data(load_data),
      .load_misaligned(load_misaligned)
  );

  initial begin
    rs2_data = 32'h1234_abcd;
    load_rdata = 32'h807f_80ff;

    funct3 = LS_B;
    addr_low = 2'b00;
    #1;
    if (store_be != 4'b0001 || store_wdata != 32'h0000_00cd || store_misaligned) begin
      $display("SB lane 0 failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    addr_low = 2'b01;
    #1;
    if (store_be != 4'b0010 || store_wdata != 32'h0000_cd00 || store_misaligned) begin
      $display("SB lane 1 failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    addr_low = 2'b10;
    #1;
    if (store_be != 4'b0100 || store_wdata != 32'h00cd_0000 || store_misaligned) begin
      $display("SB lane 2 failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    addr_low = 2'b11;
    #1;
    if (store_be != 4'b1000 || store_wdata != 32'hcd00_0000 || store_misaligned) begin
      $display("SB lane 3 failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    funct3 = LS_H;
    addr_low = 2'b00;
    #1;
    if (store_be != 4'b0011 || store_wdata != 32'h0000_abcd || store_misaligned) begin
      $display("SH low half failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    addr_low = 2'b10;
    #1;
    if (store_be != 4'b1100 || store_wdata != 32'habcd_0000 || store_misaligned) begin
      $display("SH high half failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    addr_low = 2'b01;
    #1;
    if (store_be != 4'b0000 || store_wdata != 32'h0000_0000 || !store_misaligned) begin
      $display("SH misaligned 01 failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    addr_low = 2'b11;
    #1;
    if (store_be != 4'b0000 || store_wdata != 32'h0000_0000 || !store_misaligned) begin
      $display("SH misaligned 11 failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    funct3 = LS_W;
    addr_low = 2'b00;
    #1;
    if (store_be != 4'b1111 || store_wdata != 32'h1234_abcd || store_misaligned) begin
      $display("SW aligned failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    addr_low = 2'b10;
    #1;
    if (store_be != 4'b0000 || store_wdata != 32'h0000_0000 || !store_misaligned) begin
      $display("SW misaligned failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    funct3 = 3'b111;
    addr_low = 2'b00;
    #1;
    if (store_be != 4'b0000 || store_wdata != 32'h0000_0000 || !store_misaligned) begin
      $display("Invalid store funct3 failed: be=%b wdata=%h misaligned=%b", store_be, store_wdata, store_misaligned);
      $fatal;
    end

    funct3 = LS_B;
    addr_low = 2'b00;
    #1;
    if (load_data != 32'hffff_ffff || load_misaligned) begin
      $display("LB lane 0 sign extend failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    addr_low = 2'b01;
    #1;
    if (load_data != 32'hffff_ff80 || load_misaligned) begin
      $display("LB lane 1 sign extend failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    addr_low = 2'b10;
    #1;
    if (load_data != 32'h0000_007f || load_misaligned) begin
      $display("LB lane 2 sign extend failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    addr_low = 2'b11;
    #1;
    if (load_data != 32'hffff_ff80 || load_misaligned) begin
      $display("LB lane 3 sign extend failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    funct3 = LD_LBU;
    addr_low = 2'b00;
    #1;
    if (load_data != 32'h0000_00ff || load_misaligned) begin
      $display("LBU lane 0 zero extend failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    addr_low = 2'b11;
    #1;
    if (load_data != 32'h0000_0080 || load_misaligned) begin
      $display("LBU lane 3 zero extend failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    funct3 = LS_H;
    addr_low = 2'b00;
    #1;
    if (load_data != 32'hffff_80ff || load_misaligned) begin
      $display("LH low sign extend failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    addr_low = 2'b10;
    #1;
    if (load_data != 32'hffff_807f || load_misaligned) begin
      $display("LH high sign extend failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    addr_low = 2'b01;
    #1;
    if (load_data != 32'h0000_0000 || !load_misaligned) begin
      $display("LH misaligned failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    funct3 = LD_LHU;
    addr_low = 2'b00;
    #1;
    if (load_data != 32'h0000_80ff || load_misaligned) begin
      $display("LHU low zero extend failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    addr_low = 2'b10;
    #1;
    if (load_data != 32'h0000_807f || load_misaligned) begin
      $display("LHU high zero extend failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    addr_low = 2'b11;
    #1;
    if (load_data != 32'h0000_0000 || !load_misaligned) begin
      $display("LHU misaligned failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    funct3 = LS_W;
    addr_low = 2'b00;
    #1;
    if (load_data != 32'h807f_80ff || load_misaligned) begin
      $display("LW aligned failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    addr_low = 2'b01;
    #1;
    if (load_data != 32'h0000_0000 || !load_misaligned) begin
      $display("LW misaligned failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    funct3 = 3'b111;
    addr_low = 2'b00;
    #1;
    if (load_data != 32'h0000_0000 || !load_misaligned) begin
      $display("Invalid load funct3 failed: data=%h misaligned=%b", load_data, load_misaligned);
      $fatal;
    end

    $display("load_store_unit test passed");
    $finish;
  end

endmodule
