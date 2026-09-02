
`timescale 1ns/1ps
module spi_master(
 input wire clk,rst_n,sel,we,input wire[3:0] addr,input wire[31:0] wdata,
 output reg[31:0] rdata,output reg sck,output reg mosi,input wire miso,output reg cs,output reg irq);
 reg[7:0]tx,rx;reg[3:0]bitn;reg busy;reg[15:0]div,cnt;
 always@*case(addr)0:rdata={29'b0,irq,busy,cs};1:rdata={24'b0,rx};2:rdata={24'b0,tx};3:rdata={16'b0,div};default:rdata=0;endcase
 always@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin tx<=0;rx<=0;bitn<=0;busy<=0;sck<=0;mosi<=0;cs<=1;irq<=0;div<=1;cnt<=0;end
  else begin irq<=0;
   if(sel&&we)case(addr)0:if(wdata[0])begin busy<=1;cs<=0;sck<=0;bitn<=0;mosi<=tx[7];rx<=0;bitn<=0;busy<=1;cs<=0;sck<=0;mosi<=wdata[15];cnt<=0;end 2:tx<=wdata[7:0];3:div<=wdata[15:0];endcase
   if(busy)if(cnt>=div)begin cnt<=0;if(!sck)sck<=1;else begin sck<=0;rx[7-bitn]<=miso;if(bitn==7)begin busy<=0;cs<=1;mosi<=0;irq<=1;end else begin bitn<=bitn+1;mosi<=tx[6-bitn];end end end
   else if(busy)cnt<=cnt+1;
  end
 end
endmodule
