
`timescale 1ns/1ps
module pwm(
 input wire clk,rst_n,sel,we,
 input wire[5:0] addr,
 input wire[31:0] wdata,
 output reg[31:0] rdata,
 output reg[3:0] pwm_out);
 reg[7:0] duty0,duty1,duty2,duty3;
 reg[7:0] period,count;

 always @* begin
  case(addr)
   6'd0: rdata={duty3,duty2,duty1,duty0};
   6'd1: rdata={24'b0,period};
   default: rdata=32'b0;
  endcase
 end

 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   duty0<=0; duty1<=0; duty2<=0; duty3<=0;
   period<=8'hff; count<=0; pwm_out<=0;
  end else begin
   if(count>=period) count<=0; else count<=count+1;
   pwm_out[0] <= (count<duty0);
   pwm_out[1] <= (count<duty1);
   pwm_out[2] <= (count<duty2);
   pwm_out[3] <= (count<duty3);
   if(sel&&we) begin
    case(addr)
     6'd0: begin duty0<=wdata[7:0]; duty1<=wdata[15:8];
                duty2<=wdata[23:16]; duty3<=wdata[31:24]; end
     6'd1: period<=wdata[7:0];
     default: ;
    endcase
   end
  end
 end
endmodule
