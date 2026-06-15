`timescale 1ns / 1ps

module rv32i_core #(
    parameter RESET_PC = 32'h0000_0000
) (
    input wire clk,
    input wire rst_n,

    // instruction memory (imem)
    output wire [31:0] imem_addr,  // 指令存储器地址
    input  wire [31:0] imem_rdata, // 指令存储器读数据

    // data memory (dmem)
    output wire        dmem_req,    // 数据存储器请求
    output wire        dmem_we,     // 数据存储器写使能
    output wire [ 3:0] dmem_be,     // 数据存储器字节使能
    output wire [31:0] dmem_addr,   // 数据存储器地址
    output wire [31:0] dmem_wdata,  // 数据存储器写数据
    input  wire [31:0] dmem_rdata,  // 数据存储器读数据
    input  wire        dmem_ready   // 数据存储器访问完成
);

  wire rd_we;
  wire [6:0] opcode;
  wire [4:0] rd_addr;
  wire [4:0] rs1_addr;
  wire [4:0] rs2_addr;
  wire [2:0] funct3;
  wire [6:0] funct7;
  wire [3:0] alu_op;
  wire [31:0] next_pc;
  wire [31:0] rs1_data;
  wire [31:0] rs2_data;
  wire branch;
  wire jump;
  wire branch_taken;
  wire is_jalr;
  wire [2:0] imm_sel;
  wire [31:0] imm;
  wire alu_src_imm;
  wire [31:0] alu_result;
  reg [31:0] rd_data;  // 写回寄存器内容, 通过 wb_sel 进行选择, 就算写了 reg, 实际上是使用 mux 赋值的, 所以可能综合后也是 wire.
  wire [1:0] wb_sel;  // 写回寄存器内容选择
  wire [31:0] load_data;  // load_store_unit 中读出来的数据 (不是内存原始的 32 位数据).
  wire is_auipc;
  wire mem_read;
  wire mem_write;
  wire dmem_wait;
  wire core_hold;

  // 写回寄存器数据来源
  localparam WB_ALU = 2'd0;
  localparam WB_MEM = 2'd1;
  localparam WB_PC4 = 2'd2;  // 写回 PC+4, 用于 jal/jalr 保存返回地址 rd = pc + 4
  localparam WB_IMM = 2'd3;

  // 写回数据选择 (各指令 rd 需要写入的内容不同):
  //   LUI (Load Upper Immediate): 将 20 位立即数加载到 rd 高 20 位, 低 12 位清零.
  //     典型场景: lui rd, 0x12345 -> rd = 0x1234_5000, 配合 addi (12 位立即数) 即可构造 32 位立即数.
  //   JAL (Jump And Link) / JALR (Jump And Link Register): 函数调用指令, 跳转前将
  //     返回地址 (当前 PC+4) 写入 rd (通常为 ra/x1), 供 callee 通过 ret/jalr ra 返回.
  //   LOAD 指令 -> load_data (load_store_unit 读出数据) 写入 rd.
  //   其他: R/I/AUIPC 等指令 -> ALU 运算结果写入 rd.
  always @(*) begin
    case (wb_sel)
      WB_ALU:  rd_data = alu_result;
      WB_MEM:  rd_data = load_data;
      WB_PC4:  rd_data = imem_addr + 4;
      WB_IMM:  rd_data = imm;
      // 注意这里不同于 C 语言, 及时只是 2bit 四种分支, 仍然要考虑 xz 等情况.
      // todo 看看会不会出现异常
      default: rd_data = alu_result;
    endcase
  end

  assign dmem_req  = mem_read || mem_write;
  assign dmem_we   = mem_write;
  assign dmem_addr = alu_result;
  assign dmem_wait = dmem_req && !dmem_ready;
  assign core_hold = dmem_wait;

  next_pc_unit u_next_pc_unit (
      .pc(imem_addr),
      .imm(imm),
      .rs1_data(rs1_data),
      .branch(branch),
      .branch_taken(branch_taken),
      .jump(jump),
      .is_jalr(is_jalr),

      .next_pc(next_pc)
  );

  pc_reg #(
      .RESET_PC(RESET_PC)
  ) u_pc_reg (
      .next_pc(next_pc),
      .pc(imem_addr),
      .hold(core_hold),
      .rst_n(rst_n),
      .clk(clk)
  );

  decoder u_decoder (
      .instr(imem_rdata),

      .opcode(opcode),
      .rd(rd_addr),
      .funct3(funct3),
      .rs1(rs1_addr),
      .rs2(rs2_addr),
      .funct7(funct7),

      .is_lui(),
      .is_auipc(is_auipc),
      .is_jal(),  // ???
      .is_jalr(is_jalr),
      .is_branch(),  // ???
      .is_load(),  // ???
      .is_store(),  // ???
      .is_op_imm(),  // ???
      .is_op(),  // ???

      .rd_we(rd_we),
      .alu_src_imm(alu_src_imm),
      .mem_read(mem_read),
      .mem_write(mem_write),
      .branch(branch),
      .jump(jump),

      .alu_op (alu_op),
      .imm_sel(imm_sel),
      .wb_sel (wb_sel)
  );


  regfile u_regfile (
      .clk(clk),
      .rst_n(rst_n),
      .rs1_addr(rs1_addr),
      .rs2_addr(rs2_addr),
      .rs1_data(rs1_data),
      .rs2_data(rs2_data),
      .rd_we(rd_we && !core_hold),
      .rd_addr(rd_addr),
      .rd_data(rd_data)
  );

  imm_gen u_imm_gen (
      .instr  (imem_rdata),
      .imm_sel(imm_sel),

      .imm  (imm),
      .imm_i(),
      .imm_s(),
      .imm_b(),
      .imm_u(),
      .imm_j()
  );

  alu u_alu (
      .alu_op(alu_op),
      .lhs(is_auipc ? imem_addr : rs1_data),
      .rhs(alu_src_imm ? imm : rs2_data),
      .result(alu_result)
  );

  branch_unit u_branch_unit (
      .funct3(funct3),
      .lhs(rs1_data),
      .rhs(rs2_data),
      .branch_taken(branch_taken)
  );

  load_store_unit u_load_store_unit (
      .funct3(funct3),
      .addr_low(alu_result[1:0]), // 这里使用 alu 的运算结果, 而不是直接来自 rs1/rs2.
      .rs2_data(rs2_data),
      .load_rdata(dmem_rdata),

      .store_be(dmem_be),
      .store_wdata(dmem_wdata),
      .store_misaligned(),  // todo ???

      .load_data(load_data),
      .load_misaligned()  // todo ???
  );

endmodule
