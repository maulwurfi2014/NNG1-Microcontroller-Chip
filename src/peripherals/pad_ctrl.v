`timescale 1ns/1ps
// Pad mux control for the Tiny Tapeout 8-bit bidirectional bank.
// 0 = GPIO, 1 = QSPI, 2 = SPI, 3 = I2C, 4 = UART.
module pad_ctrl(
 input wire clk,
 input wire rst_n,
 input wire sel,
 input wire we,
 input wire [3:0] addr,
 input wire [31:0] wdata,
 output reg [31:0] rdata,
 output reg [2:0] mode
);
 always @* begin
  case(addr)
   4'h0: rdata = {29'b0,mode};
   default: rdata = 32'b0;
  endcase
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
   mode <= 3'd0;
  else if(sel && we && addr==4'h0)
   mode <= wdata[2:0];
 end
endmodule
