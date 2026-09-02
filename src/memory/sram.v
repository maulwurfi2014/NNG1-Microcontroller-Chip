`timescale 1ns/1ps
module sram(input wire clk,input wire[10:0] addr,input wire we,input wire[3:0] be,
 input wire[31:0] wdata,output wire[31:0] rdata);
 reg[31:0] mem[0:2047]; integer i;
 initial for(i=0;i<2048;i=i+1)mem[i]=0;
 always@(posedge clk)if(we)begin
  if(be[0])mem[addr][7:0]<=wdata[7:0];
  if(be[1])mem[addr][15:8]<=wdata[15:8];
  if(be[2])mem[addr][23:16]<=wdata[23:16];
  if(be[3])mem[addr][31:24]<=wdata[31:24];
 end
 assign rdata=mem[addr];
endmodule
