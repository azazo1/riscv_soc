`timescale 1ns / 1ps

// 存储器控制单元
module load_store_unit (
    input wire [ 2:0] funct3,      // 指令 funct3 字段, 选择 load/store 类型 (LB/LH/LW/LBU/LHU/SB/SH/SW)
    input wire [ 1:0] addr_low,    // 有效地址低 2 位, 用于子字对齐判断; 一个字占 4 字节, 字对齐时低 2 位为 00
    input wire [31:0] rs2_data,  // rs2 寄存器值, store 时写入内存的数据
    input wire [31:0] load_rdata,  // 从数据存储器读出的原始 32 位数据, load 时根据 funct3/addr_low 截取并扩展

    // store 部分
    output reg [3:0] store_be,  // store 字节使能掩码, 每 bit 对应一个字节通道
    output reg [31:0] store_wdata,  // 对齐后的 32 位写数据, 送往数据存储器端口
    output reg store_misaligned,  // 是否是未对齐的写入, 暂时不支持未对齐的写入.

    // load 部分
    output reg [31:0] load_data,  // 读出的数据
    output reg load_misaligned  // 是否是为对齐的读取, 暂时不支持未对齐的读取.
);

  localparam LS_B = 3'b000;
  localparam LS_H = 3'b001;
  localparam LS_W = 3'b010;

  localparam LD_LB = 3'b000;  // 这三个和上面一样的, 改一个名字明确语义
  localparam LD_LH = 3'b001;
  localparam LD_LW = 3'b010;
  localparam LD_LBU = 3'b100;  // 无符号字节取 (LBU), 读出 1 字节高位填 0
  localparam LD_LHU = 3'b101;  // 无符号半字取 (LHU), 读出 2 字节高位填 0

  // store
  always @(*) begin // 据说 assign 和 always 的执行效率是差不多的, 只不过 always 可以编写复杂逻辑.
    store_be = 4'b0000;
    store_wdata = 32'b0;
    store_misaligned = 0;

    case (funct3)
      LS_B: begin  // 只存一个字节
        case (addr_low)
          2'b00: begin
            store_be = 4'b0001;
            store_wdata[7:0] = rs2_data[7:0];
          end
          2'b01: begin
            store_be = 4'b0010;
            store_wdata[15:8] = rs2_data[7:0];
          end
          2'b10: begin
            store_be = 4'b0100;
            store_wdata[23:16] = rs2_data[7:0];
          end
          2'b11: begin
            store_be = 4'b1000;
            store_wdata[31:24] = rs2_data[7:0];
          end
        endcase
      end

      LS_H: begin  // 存半字 (2 字节)
        case (addr_low)
          2'b00: begin
            store_be = 4'b0011;
            store_wdata[15:0] = rs2_data[15:0];
          end
          2'b10: begin
            store_be = 4'b1100;
            store_wdata[31:16] = rs2_data[15:0];
          end
          2'b01, 2'b11: begin
            store_misaligned = 1;
          end
        endcase
      end

      LS_W: begin  // 存一个字 (4 字节)
        case (addr_low)
          2'b00: begin
            store_be = 4'b1111;
            store_wdata[31:0] = rs2_data[31:0];
          end
          default: store_misaligned = 1;
        endcase

      end

      default: begin  // 非法存指令
        store_misaligned = 1;
      end
    endcase
  end

  // load
  always @(*) begin
    load_data = 32'b0;
    load_misaligned = 0;

    case (funct3)
      LD_LB: begin  // 只取一个字节
        case (addr_low)
          2'b00: begin
            load_data[7:0]  = load_rdata[7:0];
            load_data[31:8] = {24{load_rdata[7]}};
          end
          2'b01: begin
            load_data[7:0]  = load_rdata[15:8];
            load_data[31:8] = {24{load_rdata[15]}};
          end
          2'b10: begin
            load_data[7:0]  = load_rdata[23:16];
            load_data[31:8] = {24{load_rdata[23]}};
          end
          2'b11: begin
            load_data[7:0]  = load_rdata[31:24];
            load_data[31:8] = {24{load_rdata[31]}};
          end
        endcase
      end

      LD_LH: begin  // 取半字 (2 字节)
        case (addr_low)
          2'b00: begin
            load_data[15:0]  = load_rdata[15:0];
            load_data[31:16] = {16{load_rdata[15]}};
          end
          2'b10: begin
            load_data[15:0]  = load_rdata[31:16];
            load_data[31:16] = {16{load_rdata[31]}};
          end
          2'b01, 2'b11: begin
            load_misaligned = 1;
          end
        endcase
      end

      LD_LW: begin  // 取一个字 (4 字节)
        case (addr_low)
          2'b00: begin
            load_data = load_rdata;
          end
          default: load_misaligned = 1;
        endcase
      end

      LD_LBU: begin  // 取一个字节 (无符号, 高位补 0)
        load_data[31:8] = 0;
        case (addr_low)
          2'b00: begin
            load_data[7:0] = load_rdata[7:0];
          end
          2'b01: begin
            load_data[7:0] = load_rdata[15:8];
          end
          2'b10: begin
            load_data[7:0] = load_rdata[23:16];
          end
          2'b11: begin
            load_data[7:0] = load_rdata[31:24];
          end
        endcase
      end

      LD_LHU: begin  // 取半字 (无符号, 高位补 0)
        load_data[31:16] = 0;
        case (addr_low)
          2'b00: begin
            load_data[15:0] = load_rdata[15:0];
          end
          2'b10: begin
            load_data[15:0] = load_rdata[31:16];
          end
          2'b01, 2'b11: begin
            load_misaligned = 1;
          end
        endcase
      end

      default: begin  // 非法取指令
        load_misaligned = 1;
      end
    endcase
  end
endmodule
