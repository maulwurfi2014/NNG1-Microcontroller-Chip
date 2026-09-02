`timescale 1ns/1ps
module i2c_master(
 input wire clk,rst_n,sel,we,input wire[3:0] addr,input wire[31:0] wdata,
 output reg[31:0] rdata,output reg scl_oe,output reg sda_oe,input wire sda_in,
 output reg busy,output reg irq);
 reg[15:0] div,cnt; reg[3:0] bitn; reg[7:0] tx; reg phase;
 always @* case(addr)
 4'h0:rdata={28'b0,irq,busy,sda_in,1'b0};
 4'h1:rdata={24'b0,tx};
 4'h2:rdata={16'b0,div};
 default:rdata=0;
 endcase
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin div<=1;cnt<=0;bitn<=0;tx<=0;busy<=0;irq<=0;scl_oe<=0;sda_oe<=0;phase<=0;end
  else begin
   irq<=0;
   if(sel&&we) case(addr)
    4'h0: if(wdata[0]&&!busy) begin busy<=1;bitn<=0;phase<=0;scl_oe<=0;sda_oe<=1;cnt<=0;end
    4'h1: tx<=wdata[7:0];
    4'h2: div<=wdata[15:0];
   endcase
   if(busy) begin
    if(cnt>=div) begin
     cnt<=0;
     if(!phase) begin scl_oe<=1;sda_oe<=tx[7-bitn];phase<=1;end
     else begin
      scl_oe<=0;phase<=0;
      if(bitn==7) begin busy<=0;sda_oe<=0;irq<=1;end
      else bitn<=bitn+1;
     end
    end else cnt<=cnt+1;
   end
  end
 end
endmodule
