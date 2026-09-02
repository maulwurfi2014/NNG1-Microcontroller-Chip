
`timescale 1ns/1ps
module irq_controller(input wire clk,rst_n,sel,we,input wire[3:0]addr,input wire[31:0]wdata,output reg[31:0]rdata,input wire[7:0]irq_sources,output wire irq);
 reg[7:0]enable,pending;assign irq=|(enable&pending);
 always@*case(addr)0:rdata={24'b0,enable};1:rdata={24'b0,pending};default:rdata=0;endcase
 always@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin enable<=0;pending<=0;end else begin pending<=pending|irq_sources;if(sel&&we)case(addr)0:enable<=wdata[7:0];1:pending<=pending&~wdata[7:0];endcase end
 end
endmodule
