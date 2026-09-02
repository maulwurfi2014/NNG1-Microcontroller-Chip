`timescale 1ns/1ps
// IHP SG13G2 SRAM hook for a future macro-based build.
// The PDK supplies this exact macro name and a one-cycle memory interface.
// Do not instantiate this module in the default Tiny Tapeout RTL build yet:
// the current RV32I core exposes an asynchronous data-read interface.
module nng1_ihp_sram_1024x32(
 input wire clk,
 input wire en,
 input wire we,
 input wire [31:0] wdata,
 input wire [31:0] wmask,
 input wire [9:0] addr,
 output wire [31:0] rdata
);
`ifdef NNG1_USE_IHP_SRAM
 RM_IHPSG13_1P_1024x32_c2_bm_bist u_sram (
   .A_CLK(clk),
   .A_MEN(en),
   .A_WEN(we),
   .A_REN(en && !we),
   .A_ADDR(addr),
   .A_DIN(wdata),
   .A_DLY(1'b1),
   .A_DOUT(rdata),
   .A_BM(wmask),
   .A_BIST_CLK(1'b0),
   .A_BIST_EN(1'b0),
   .A_BIST_MEN(1'b0),
   .A_BIST_WEN(1'b0),
   .A_BIST_REN(1'b0),
   .A_BIST_ADDR(10'b0),
   .A_BIST_DIN(32'b0),
   .A_BIST_BM(32'b0)
 );
`else
 reg [31:0] mem [0:1023];
 integer i;
 initial for(i=0;i<1024;i=i+1) mem[i]=32'b0;
 always @(posedge clk) begin
   if(en && we) begin
     if(wmask[7:0]   != 8'h00) mem[addr][7:0]   <= wdata[7:0];
     if(wmask[15:8]  != 8'h00) mem[addr][15:8]  <= wdata[15:8];
     if(wmask[23:16] != 8'h00) mem[addr][23:16] <= wdata[23:16];
     if(wmask[31:24] != 8'h00) mem[addr][31:24] <= wdata[31:24];
   end
 end
 assign rdata = mem[addr];
`endif
endmodule
