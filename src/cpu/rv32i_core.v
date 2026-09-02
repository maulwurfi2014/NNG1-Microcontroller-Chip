`timescale 1ns/1ps
module rv32i_core(
 input wire clk, input wire rst_n,
 output wire [31:0] imem_addr,
 input wire [31:0] imem_rdata,
 output reg [31:0] dmem_addr,
 output reg [31:0] dmem_wdata,
 input wire [31:0] dmem_rdata,
 output reg dmem_we,
 output reg [3:0] dmem_be,
 input wire irq
);
 reg [31:0] pc;
 reg [31:0] regs[0:31];
 integer i;

 assign imem_addr = pc;

 wire [6:0] opcode = imem_rdata[6:0];
 wire [4:0] rd = imem_rdata[11:7];
 wire [2:0] funct3 = imem_rdata[14:12];
 wire [4:0] rs1 = imem_rdata[19:15];
 wire [4:0] rs2 = imem_rdata[24:20];
 wire [6:0] funct7 = imem_rdata[31:25];

 wire [31:0] a = (rs1 == 0) ? 32'b0 : regs[rs1];
 wire [31:0] b = (rs2 == 0) ? 32'b0 : regs[rs2];

 reg [31:0] next_pc, wb_data;
 reg wb_en;
 reg [4:0] wb_rd;
 reg [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

 always @* begin
  imm_i = {{20{imem_rdata[31]}}, imem_rdata[31:20]};
  imm_s = {{20{imem_rdata[31]}}, imem_rdata[31:25], imem_rdata[11:7]};
  imm_b = {{19{imem_rdata[31]}}, imem_rdata[31], imem_rdata[7],
           imem_rdata[30:25], imem_rdata[11:8], 1'b0};
  imm_u = {imem_rdata[31:12], 12'b0};
  imm_j = {{11{imem_rdata[31]}}, imem_rdata[31], imem_rdata[19:12],
           imem_rdata[20], imem_rdata[30:21], 1'b0};

  next_pc = pc + 32'd4;
  wb_data = 32'b0;
  wb_en = 1'b0;
  wb_rd = rd;

  dmem_addr = 32'b0;
  dmem_wdata = 32'b0;
  dmem_we = 1'b0;
  dmem_be = 4'b0;

  case (opcode)
    7'b0110111: begin
      wb_en = (rd != 0); wb_data = imm_u;                 // LUI
    end
    7'b0010111: begin
      wb_en = (rd != 0); wb_data = pc + imm_u;            // AUIPC
    end
    7'b1101111: begin
      wb_en = (rd != 0); wb_data = pc + 4; next_pc = pc + imm_j; // JAL
    end
    7'b1100111: begin
      if (funct3 == 3'b000) begin
        wb_en = (rd != 0); wb_data = pc + 4;
        next_pc = (a + imm_i) & 32'hffff_fffe;             // JALR
      end
    end
    7'b1100011: begin
      case (funct3)
        3'b000: if (a == b) next_pc = pc + imm_b;                         // BEQ
        3'b001: if (a != b) next_pc = pc + imm_b;                         // BNE
        3'b100: if ($signed(a) <  $signed(b)) next_pc = pc + imm_b;      // BLT
        3'b101: if ($signed(a) >= $signed(b)) next_pc = pc + imm_b;      // BGE
        3'b110: if (a < b) next_pc = pc + imm_b;                          // BLTU
        3'b111: if (a >= b) next_pc = pc + imm_b;                         // BGEU
        default: ;
      endcase
    end
    7'b0000011: begin
      dmem_addr = a + imm_i;
      wb_en = (rd != 0);
      case (funct3)
        3'b000: begin // LB
          case (dmem_addr[1:0])
            2'd0: wb_data={{24{dmem_rdata[7]}},dmem_rdata[7:0]};
            2'd1: wb_data={{24{dmem_rdata[15]}},dmem_rdata[15:8]};
            2'd2: wb_data={{24{dmem_rdata[23]}},dmem_rdata[23:16]};
            2'd3: wb_data={{24{dmem_rdata[31]}},dmem_rdata[31:24]};
          endcase
        end
        3'b001: wb_data = dmem_addr[1] ?
          {{16{dmem_rdata[31]}},dmem_rdata[31:16]} :
          {{16{dmem_rdata[15]}},dmem_rdata[15:0]}; // LH
        3'b010: wb_data = dmem_rdata;                 // LW
        3'b100: begin                                 // LBU
          case (dmem_addr[1:0])
            2'd0: wb_data={24'b0,dmem_rdata[7:0]};
            2'd1: wb_data={24'b0,dmem_rdata[15:8]};
            2'd2: wb_data={24'b0,dmem_rdata[23:16]};
            2'd3: wb_data={24'b0,dmem_rdata[31:24]};
          endcase
        end
        3'b101: wb_data = dmem_addr[1] ?
          {16'b0,dmem_rdata[31:16]} :
          {16'b0,dmem_rdata[15:0]};                 // LHU
        default: wb_en = 1'b0;
      endcase
    end
    7'b0100011: begin
      dmem_addr = a + imm_s;
      dmem_we = 1'b1;
      case (funct3)
        3'b000: begin
          dmem_be = 4'b0001 << dmem_addr[1:0];
          dmem_wdata = b << (8*dmem_addr[1:0]);
        end
        3'b001: begin
          dmem_be = dmem_addr[1] ? 4'b1100 : 4'b0011;
          dmem_wdata = b << (16*dmem_addr[1]);
        end
        3'b010: begin
          dmem_be = 4'b1111;
          dmem_wdata = b;
        end
        default: begin dmem_we=1'b0; dmem_be=4'b0; end
      endcase
    end
    7'b0010011: begin
      wb_en = (rd != 0);
      case (funct3)
        3'b000: wb_data=a+imm_i;                         // ADDI
        3'b010: wb_data=($signed(a)<$signed(imm_i));     // SLTI
        3'b011: wb_data=(a<imm_i);                       // SLTIU
        3'b100: wb_data=a^imm_i;                         // XORI
        3'b110: wb_data=a|imm_i;                         // ORI
        3'b111: wb_data=a&imm_i;                         // ANDI
        3'b001: if (funct7==7'b0000000) wb_data=a<<imem_rdata[24:20]; else wb_en=0;
        3'b101: begin
          if (funct7==7'b0000000) wb_data=a>>imem_rdata[24:20];
          else if (funct7==7'b0100000) wb_data=$signed(a)>>>imem_rdata[24:20];
          else wb_en=0;
        end
        default: wb_en=0;
      endcase
    end
    7'b0110011: begin
      wb_en = (rd != 0);
      case (funct3)
        3'b000: if (funct7==0) wb_data=a+b; else if (funct7==7'b0100000) wb_data=a-b; else wb_en=0;
        3'b001: if (funct7==0) wb_data=a<<b[4:0]; else wb_en=0;
        3'b010: if (funct7==0) wb_data=($signed(a)<$signed(b)); else wb_en=0;
        3'b011: if (funct7==0) wb_data=(a<b); else wb_en=0;
        3'b100: if (funct7==0) wb_data=a^b; else wb_en=0;
        3'b101: if (funct7==0) wb_data=a>>b[4:0];
                  else if (funct7==7'b0100000) wb_data=$signed(a)>>>b[4:0];
                  else wb_en=0;
        3'b110: if (funct7==0) wb_data=a|b; else wb_en=0;
        3'b111: if (funct7==0) wb_data=a&b; else wb_en=0;
        default: wb_en=0;
      endcase
    end
    default: ;
  endcase
 end

 always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    pc <= 32'b0;
    for (i=0;i<32;i=i+1) regs[i] <= 32'b0;
  end else begin
    pc <= next_pc;
    if (wb_en && wb_rd != 0)
      regs[wb_rd] <= wb_data;
    regs[0] <= 32'b0;
  end
 end
endmodule
