
`timescale 1ns/1ps
module clock_ctrl(input wire clk,rst_n,input wire[7:0]div_sel,output wire clk_en);
 reg[7:0]count;always@(posedge clk or negedge rst_n)if(!rst_n)count<=0;else if(count>=div_sel)count<=0;else count<=count+1;assign clk_en=(count==0);
endmodule
