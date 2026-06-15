`timescale 1ns / 1ps

module decoder_vlg_tst;

  reg [31:0] instr;

  wire [6:0] opcode;
  wire [4:0] rd;
  wire [4:0] rs1;
  wire [4:0] rs2;
  wire [2:0] funct3;
  wire [6:0] funct7;
  wire is_lui;
  wire is_auipc;
  wire is_jal;
  wire is_jalr;
  wire is_branch;
  wire is_load;
  wire is_store;
  wire is_op_imm;
  wire is_op;
  wire rd_we;
  wire alu_src_imm;
  wire mem_read;
  wire mem_write;
  wire branch;
  wire jump;
  wire [4:0] alu_op;
  wire [2:0] imm_sel;
  wire [1:0] wb_sel;

  localparam ALU_ADD = 5'd0;
  localparam ALU_SUB = 5'd1;
  localparam ALU_SLL = 5'd2;
  localparam ALU_SLT = 5'd3;
  localparam ALU_SLTU = 5'd4;
  localparam ALU_XOR = 5'd5;
  localparam ALU_SRL = 5'd6;
  localparam ALU_SRA = 5'd7;
  localparam ALU_OR = 5'd8;
  localparam ALU_AND = 5'd9;
  localparam ALU_MUL = 5'd10;
  localparam ALU_MULH = 5'd11;
  localparam ALU_MULHSU = 5'd12;
  localparam ALU_MULHU = 5'd13;
  localparam ALU_DIV = 5'd14;
  localparam ALU_DIVU = 5'd15;
  localparam ALU_REM = 5'd16;
  localparam ALU_REMU = 5'd17;

  localparam IMM_I = 3'd0;
  localparam IMM_S = 3'd1;
  localparam IMM_B = 3'd2;
  localparam IMM_U = 3'd3;
  localparam IMM_J = 3'd4;

  localparam WB_ALU = 2'd0;
  localparam WB_MEM = 2'd1;
  localparam WB_PC4 = 2'd2;
  localparam WB_IMM = 2'd3;

	  decoder dut (
      .instr(instr),
      .opcode(opcode),
      .rd(rd),
      .rs1(rs1),
      .rs2(rs2),
      .funct3(funct3),
      .funct7(funct7),
      .is_lui(is_lui),
      .is_auipc(is_auipc),
      .is_jal(is_jal),
      .is_jalr(is_jalr),
      .is_branch(is_branch),
      .is_load(is_load),
      .is_store(is_store),
      .is_op_imm(is_op_imm),
      .is_op(is_op),
      .rd_we(rd_we),
      .alu_src_imm(alu_src_imm),
      .mem_read(mem_read),
      .mem_write(mem_write),
      .branch(branch),
      .jump(jump),
      .alu_op(alu_op),
      .imm_sel(imm_sel),
      .wb_sel(wb_sel)
	  );

  task expect_alu_op;
    input [4:0] expected;
    input [31:0] check_id;
    begin
      #1;
      if (alu_op != expected) begin
        $display("check %0d alu_op failed: expected %d, got %d", check_id, expected, alu_op);
        $fatal;
      end
    end
  endtask

  initial begin
    // R-type: sub x5, x6, x7
    instr = {7'b0100000, 5'd7, 5'd6, 3'b000, 5'd5, 7'b0110011};
    #1;
    if (opcode != 7'b0110011 || rd != 5'd5 || rs1 != 5'd6 || rs2 != 5'd7 || funct3 != 3'b000 || funct7 != 7'b0100000) begin
      $display("R-type fields failed");
      $fatal;
    end
    if (!is_op || is_op_imm || is_load || is_store || is_branch || is_lui || is_auipc || is_jal || is_jalr) begin
      $display("R-type opcode class failed");
      $fatal;
    end
    if (!rd_we || alu_src_imm || mem_read || mem_write || branch || jump) begin
      $display("R-type control failed");
      $fatal;
    end
    if (alu_op != ALU_SUB) begin
      $display("R-type SUB alu_op failed: got %d", alu_op);
      $fatal;
    end
    if (imm_sel != IMM_I || wb_sel != WB_ALU) begin
      $display("R-type select failed: imm_sel=%d wb_sel=%d", imm_sel, wb_sel);
      $fatal;
    end

    // R-type: add x5, x6, x7
    instr = {7'b0000000, 5'd7, 5'd6, 3'b000, 5'd5, 7'b0110011};
    #1;
	    if (alu_op != ALU_ADD) begin
	      $display("R-type ADD alu_op failed: got %d", alu_op);
	      $fatal;
	    end

    // R-type RV32M: funct7=0000001.
    instr = {7'b0000001, 5'd7, 5'd6, 3'b000, 5'd5, 7'b0110011}; // mul
    expect_alu_op(ALU_MUL, 32'd101);

    instr = {7'b0000001, 5'd7, 5'd6, 3'b001, 5'd5, 7'b0110011}; // mulh
    expect_alu_op(ALU_MULH, 32'd102);

    instr = {7'b0000001, 5'd7, 5'd6, 3'b010, 5'd5, 7'b0110011}; // mulhsu
    expect_alu_op(ALU_MULHSU, 32'd103);

    instr = {7'b0000001, 5'd7, 5'd6, 3'b011, 5'd5, 7'b0110011}; // mulhu
    expect_alu_op(ALU_MULHU, 32'd104);

    instr = {7'b0000001, 5'd7, 5'd6, 3'b100, 5'd5, 7'b0110011}; // div
    expect_alu_op(ALU_DIV, 32'd105);

    instr = {7'b0000001, 5'd7, 5'd6, 3'b101, 5'd5, 7'b0110011}; // divu
    expect_alu_op(ALU_DIVU, 32'd106);

    instr = {7'b0000001, 5'd7, 5'd6, 3'b110, 5'd5, 7'b0110011}; // rem
    expect_alu_op(ALU_REM, 32'd107);

    instr = {7'b0000001, 5'd7, 5'd6, 3'b111, 5'd5, 7'b0110011}; // remu
    expect_alu_op(ALU_REMU, 32'd108);

    // I-type OP-IMM: addi x1, x2, 0x123
    instr = {12'h123, 5'd2, 3'b000, 5'd1, 7'b0010011};
    #1;
    if (opcode != 7'b0010011 || rd != 5'd1 || rs1 != 5'd2 || funct3 != 3'b000) begin
      $display("OP-IMM fields failed");
      $fatal;
    end
    if (!is_op_imm || is_op || is_load || is_store || is_branch || is_lui || is_auipc || is_jal || is_jalr) begin
      $display("OP-IMM opcode class failed");
      $fatal;
    end
    if (!rd_we || !alu_src_imm || mem_read || mem_write || branch || jump) begin
      $display("OP-IMM control failed");
      $fatal;
    end
    if (alu_op != ALU_ADD) begin
      $display("OP-IMM ADDI alu_op failed: got %d", alu_op);
      $fatal;
    end

    // OP-IMM must not decode funct7-like bits as SUB.
    instr = {7'b0100000, 5'd1, 5'd2, 3'b000, 5'd1, 7'b0010011};
    #1;
    if (alu_op != ALU_ADD) begin
      $display("OP-IMM ADDI with high bits alu_op failed: got %d", alu_op);
      $fatal;
    end
    if (imm_sel != IMM_I || wb_sel != WB_ALU) begin
      $display("OP-IMM select failed: imm_sel=%d wb_sel=%d", imm_sel, wb_sel);
      $fatal;
    end

    // Shift and logic ALU operations.
    instr = {7'b0000000, 5'd7, 5'd6, 3'b001, 5'd5, 7'b0110011};
    #1;
    if (alu_op != ALU_SLL) begin
      $display("SLL alu_op failed: got %d", alu_op);
      $fatal;
    end

    instr = {7'b0000000, 5'd7, 5'd6, 3'b010, 5'd5, 7'b0110011};
    #1;
    if (alu_op != ALU_SLT) begin
      $display("SLT alu_op failed: got %d", alu_op);
      $fatal;
    end

    instr = {7'b0000000, 5'd7, 5'd6, 3'b011, 5'd5, 7'b0110011};
    #1;
    if (alu_op != ALU_SLTU) begin
      $display("SLTU alu_op failed: got %d", alu_op);
      $fatal;
    end

    instr = {7'b0000000, 5'd7, 5'd6, 3'b100, 5'd5, 7'b0110011};
    #1;
    if (alu_op != ALU_XOR) begin
      $display("XOR alu_op failed: got %d", alu_op);
      $fatal;
    end

    instr = {7'b0000000, 5'd7, 5'd6, 3'b101, 5'd5, 7'b0110011};
    #1;
    if (alu_op != ALU_SRL) begin
      $display("SRL alu_op failed: got %d", alu_op);
      $fatal;
    end

    instr = {7'b0100000, 5'd7, 5'd6, 3'b101, 5'd5, 7'b0110011};
    #1;
    if (alu_op != ALU_SRA) begin
      $display("SRA alu_op failed: got %d", alu_op);
      $fatal;
    end

    instr = {7'b0000000, 5'd7, 5'd6, 3'b110, 5'd5, 7'b0110011};
    #1;
    if (alu_op != ALU_OR) begin
      $display("OR alu_op failed: got %d", alu_op);
      $fatal;
    end

    instr = {7'b0000000, 5'd7, 5'd6, 3'b111, 5'd5, 7'b0110011};
    #1;
    if (alu_op != ALU_AND) begin
      $display("AND alu_op failed: got %d", alu_op);
      $fatal;
    end

    // Load: lw x3, 8(x4)
    instr = {12'd8, 5'd4, 3'b010, 5'd3, 7'b0000011};
    #1;
    if (!is_load || is_store || is_op || is_op_imm || is_branch || is_lui || is_auipc || is_jal || is_jalr) begin
      $display("LOAD opcode class failed");
      $fatal;
    end
    if (!rd_we || !alu_src_imm || !mem_read || mem_write || branch || jump) begin
      $display("LOAD control failed");
      $fatal;
    end
    if (imm_sel != IMM_I || wb_sel != WB_MEM) begin
      $display("LOAD select failed: imm_sel=%d wb_sel=%d", imm_sel, wb_sel);
      $fatal;
    end

    // Store: sw x3, 8(x4)
    instr = {7'b0000000, 5'd3, 5'd4, 3'b010, 5'b01000, 7'b0100011};
    #1;
    if (!is_store || is_load || is_op || is_op_imm || is_branch || is_lui || is_auipc || is_jal || is_jalr) begin
      $display("STORE opcode class failed");
      $fatal;
    end
    if (rd_we || !alu_src_imm || mem_read || !mem_write || branch || jump) begin
      $display("STORE control failed");
      $fatal;
    end
    if (imm_sel != IMM_S || wb_sel != WB_ALU) begin
      $display("STORE select failed: imm_sel=%d wb_sel=%d", imm_sel, wb_sel);
      $fatal;
    end

    // Branch: beq x1, x2, 16
    instr = {1'b0, 6'b000000, 5'd2, 5'd1, 3'b000, 4'b1000, 1'b0, 7'b1100011};
    #1;
    if (!is_branch || is_load || is_store || is_op || is_op_imm || is_lui || is_auipc || is_jal || is_jalr) begin
      $display("BRANCH opcode class failed");
      $fatal;
    end
    if (rd_we || alu_src_imm || mem_read || mem_write || !branch || jump) begin
      $display("BRANCH control failed");
      $fatal;
    end
    if (imm_sel != IMM_B || wb_sel != WB_ALU) begin
      $display("BRANCH select failed: imm_sel=%d wb_sel=%d", imm_sel, wb_sel);
      $fatal;
    end

    // U/J classes.
    instr = {20'h12345, 5'd8, 7'b0110111};
    #1;
    if (!is_lui || is_auipc || is_jal || is_jalr || is_branch || is_load || is_store || is_op_imm || is_op) begin
      $display("LUI opcode class failed");
      $fatal;
    end
    if (!rd_we || !alu_src_imm || mem_read || mem_write || branch || jump) begin
      $display("LUI control failed");
      $fatal;
    end
    if (imm_sel != IMM_U || wb_sel != WB_IMM) begin
      $display("LUI select failed: imm_sel=%d wb_sel=%d", imm_sel, wb_sel);
      $fatal;
    end

    instr = {20'h12345, 5'd8, 7'b0010111};
    #1;
    if (!is_auipc || is_lui || is_jal || is_jalr || is_branch || is_load || is_store || is_op_imm || is_op) begin
      $display("AUIPC opcode class failed");
      $fatal;
    end
    if (!rd_we || !alu_src_imm || mem_read || mem_write || branch || jump) begin
      $display("AUIPC control failed");
      $fatal;
    end
    if (imm_sel != IMM_U || wb_sel != WB_ALU) begin
      $display("AUIPC select failed: imm_sel=%d wb_sel=%d", imm_sel, wb_sel);
      $fatal;
    end

    instr = {20'h00001, 5'd1, 7'b1101111};
    #1;
    if (!is_jal || is_lui || is_auipc || is_jalr || is_branch || is_load || is_store || is_op_imm || is_op) begin
      $display("JAL opcode class failed");
      $fatal;
    end
    if (!rd_we || alu_src_imm || mem_read || mem_write || branch || !jump) begin
      $display("JAL control failed");
      $fatal;
    end
    if (imm_sel != IMM_J || wb_sel != WB_PC4) begin
      $display("JAL select failed: imm_sel=%d wb_sel=%d", imm_sel, wb_sel);
      $fatal;
    end

    instr = {12'd0, 5'd1, 3'b000, 5'd1, 7'b1100111};
    #1;
    if (!is_jalr || is_lui || is_auipc || is_jal || is_branch || is_load || is_store || is_op_imm || is_op) begin
      $display("JALR opcode class failed");
      $fatal;
    end
    if (!rd_we || !alu_src_imm || mem_read || mem_write || branch || !jump) begin
      $display("JALR control failed");
      $fatal;
    end
    if (imm_sel != IMM_I || wb_sel != WB_PC4) begin
      $display("JALR select failed: imm_sel=%d wb_sel=%d", imm_sel, wb_sel);
      $fatal;
    end

    $display("decoder test passed");
    $finish;
  end

endmodule
