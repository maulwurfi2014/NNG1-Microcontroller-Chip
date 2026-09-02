`timescale 1ns/1ps
module gpio#(parameter WIDTH=20)(
 input wire clk,rst_n,sel,we,
 input wire[3:0] addr,
 input wire[31:0] wdata,
 output reg[31:0] rdata,
 input wire[WIDTH-1:0] gpio_in,
 output reg[WIDTH-1:0] gpio_out,
 output reg[WIDTH-1:0] gpio_oe
);
 always @* begin
  case(addr)
   4'h0:rdata={{(32-WIDTH){1'b0}},gpio_out}; // +0 OUT
   4'h1:rdata={{(32-WIDTH){1'b0}},gpio_in};  // +4 IN
   4'h2:rdata={{(32-WIDTH){1'b0}},gpio_oe};   // +8 OE
   default:rdata=32'b0;
  endcase
 end
 always@(posedge clk or negedge rst_n)
  if(!rst_n)begin gpio_out<=0;gpio_oe<=0;end
  else if(sel&&we) case(addr)
   4'h0:gpio_out<=wdata[WIDTH-1:0];
   4'h2:gpio_oe<=wdata[WIDTH-1:0];
   default:;
  endcase
endmodule
