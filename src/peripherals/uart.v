
`timescale 1ns/1ps
module uart #(parameter DIV=4)(
 input wire clk,rst_n,sel,we,input wire[3:0] addr,input wire[31:0] wdata,
 output reg[31:0] rdata,input wire rx,output reg tx,output reg irq_rx,output reg irq_tx);
 reg[15:0]baud_div;reg[7:0]tx_data,rx_data;reg[3:0]tx_bit,rx_bit;reg[15:0]tx_cnt,rx_cnt;reg tx_busy,rx_busy;
 always@*case(addr)0:rdata={28'b0,tx_busy,irq_tx,irq_rx};1:rdata={24'b0,rx_data};2:rdata={30'b0,irq_tx,irq_rx};3:rdata={16'b0,baud_div};default:rdata=0;endcase
 always@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin baud_div<=DIV;tx<=1;irq_rx<=0;irq_tx<=0;tx_busy<=0;rx_busy<=0;tx_bit<=0;rx_bit<=0;tx_cnt<=0;rx_cnt<=0;rx_data<=0;end
  else begin
   irq_rx<=0;irq_tx<=0;
   if(sel&&we)case(addr)0:if(!tx_busy)begin tx_data<=wdata[7:0];tx_busy<=1;tx_bit<=0;tx_cnt<=0;tx<=0;end 2:begin irq_rx<=wdata[1];irq_tx<=wdata[0];end 3:baud_div<=wdata[15:0];endcase
   if(tx_busy)begin
    if(tx_cnt>=baud_div)begin tx_cnt<=0;
     case(tx_bit)0:tx<=tx_data[0];1:tx<=tx_data[1];2:tx<=tx_data[2];3:tx<=tx_data[3];4:tx<=tx_data[4];5:tx<=tx_data[5];6:tx<=tx_data[6];7:tx<=tx_data[7];8:tx<=1;default:begin tx<=1;tx_busy<=0;irq_tx<=1;end endcase
     if(tx_bit<9)tx_bit<=tx_bit+1;
    end else tx_cnt<=tx_cnt+1;
   end
   if(!rx_busy&&!rx)begin rx_busy<=1;rx_bit<=0;rx_cnt<=baud_div>>1;end
   else if(rx_busy&&rx_cnt!=0)rx_cnt<=rx_cnt-1;
   else if(rx_busy)begin rx_cnt<=baud_div;if(rx_bit<8)begin rx_data[rx_bit]<=rx;rx_bit<=rx_bit+1;end else begin rx_busy<=0;irq_rx<=1;end end
  end
 end
endmodule
