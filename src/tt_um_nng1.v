`timescale 1ns/1ps
module tt_um_nng1(
 input wire [7:0] ui_in,
 output wire [7:0] uo_out,
 input wire [7:0] uio_in,
 output wire [7:0] uio_out,
 output wire [7:0] uio_oe,
 input wire ena,
 input wire clk,
 input wire rst_n
);
 nng1 core(
  .clk(clk), .rst_n(rst_n), .ena(ena),
  .ui_in(ui_in), .uo_out(uo_out),
  .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),
  .test_mode(1'b0), .test_rdata(32'b0)
 );
endmodule
