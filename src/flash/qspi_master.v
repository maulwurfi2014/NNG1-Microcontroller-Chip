`timescale 1ns/1ps
module qspi_master(
 input wire clk,rst_n,sel,we,input wire[4:0] addr,input wire[31:0] wdata,
 output reg[31:0] rdata,output reg cs,output reg sck,output reg[3:0] io_oe,
 input wire[3:0] io_in,output reg[3:0] io_out,output reg busy,output reg irq);
 reg[31:0]tx,tx_shift,rx;reg[6:0]bitn;reg[15:0]div,cnt;
 always @* case(addr)
 5'h00:rdata={28'b0,irq,busy,cs};
 5'h01:rdata=rx;
 5'h02:rdata=tx;
 5'h03:rdata={16'b0,div};
 default:rdata=0;
 endcase
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin cs<=1;sck<=0;io_oe<=0;io_out<=0;busy<=0;irq<=0;tx<=0;tx_shift<=0;rx<=0;bitn<=0;div<=1;cnt<=0;end
  else begin
   irq<=0;
   if(sel&&we) case(addr)
    5'h00: if(wdata[0]) begin busy<=1;cs<=0;bitn<=0;io_oe<=4'b1111;cnt<=0;sck<=0;tx_shift<=tx;end
    5'h02: tx<=wdata;
    5'h03: div<=wdata[15:0];
    default:;
   endcase
   if(busy) begin
    if(cnt>=div) begin
     cnt<=0;sck<=~sck;
     if(!sck) begin io_out<=tx_shift[31:28];rx<={rx[27:0],io_in};tx_shift<=tx_shift<<4;end
     else if(bitn>=64) begin busy<=0;cs<=1;io_oe<=0;irq<=1;end
     else bitn<=bitn+4;
    end else cnt<=cnt+1;
   end
  end
 end
endmodule
