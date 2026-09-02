
`timescale 1ns/1ps
module timer(input wire clk,rst_n,sel,we,input wire[3:0]addr,input wire[31:0]wdata,output reg[31:0]rdata,output reg irq0,output reg irq1);
 reg[31:0]cnt0,cmp0,cnt1,cmp1;reg en0,en1;
 always@*case(addr)0:rdata=cnt0;1:rdata=cmp0;2:rdata=cnt1;3:rdata=cmp1;4:rdata={30'b0,en1,en0};default:rdata=0;endcase
 always@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin cnt0<=0;cmp0<=0;cnt1<=0;cmp1<=0;en0<=0;en1<=0;irq0<=0;irq1<=0;end
  else begin irq0<=0;irq1<=0;if(en0)begin cnt0<=cnt0+1;if(cmp0!=0&&cnt0+1>=cmp0)begin cnt0<=0;irq0<=1;end end if(en1)begin cnt1<=cnt1+1;if(cmp1!=0&&cnt1+1>=cmp1)begin cnt1<=0;irq1<=1;end end if(sel&&we)case(addr)1:cmp0<=wdata;3:cmp1<=wdata;4:begin en0<=wdata[0];en1<=wdata[1];end endcase end
 end
endmodule
