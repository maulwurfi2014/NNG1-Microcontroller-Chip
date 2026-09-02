
`timescale 1ns/1ps
module watchdog(input wire clk,rst_n,sel,we,input wire[3:0]addr,input wire[31:0]wdata,output reg[31:0]rdata,output reg irq,output reg reset_req);
 reg[31:0]limit,count;reg enable;
 always@*case(addr)0:rdata=count;1:rdata=limit;2:rdata={31'b0,enable};default:rdata=0;endcase
 always@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin limit<=0;count<=0;enable<=0;irq<=0;reset_req<=0;end
  else begin irq<=0;reset_req<=0;if(sel&&we)case(addr)1:begin limit<=wdata;count<=0;end 2:begin enable<=wdata[0];if(!wdata[0])count<=0;end 3:count<=0;endcase if(enable&&limit!=0)if(count>=limit)begin count<=0;irq<=1;reset_req<=1;end else count<=count+1;end
 end
endmodule
