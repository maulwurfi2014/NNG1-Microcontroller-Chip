`timescale 1ns/1ps
module bootrom(input wire[7:0] addr, output reg[31:0] rdata);
 always @* begin
  case(addr)
   8'd0:rdata=32'h00100093;
   8'd1:rdata=32'h00200113;
   8'd2:rdata=32'h002081b3;
   8'd3:rdata=32'h0000006f;
   default:rdata=32'h00000013;
  endcase
 end
endmodule
