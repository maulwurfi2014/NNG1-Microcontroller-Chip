`timescale 1ns/1ps
module nng1_qspi_byte_phy #(
    parameter integer HALF_DIV = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tx_byte,
    output reg [7:0] rx_byte,
    output reg busy,
    output reg done,
    output reg sck,
    output reg cs,
    output reg [3:0] io_oe,
    output reg [3:0] io_out,
    input wire [3:0] io_in
);
    reg [2:0] bitn;
    reg [15:0] divcnt;
    reg phase; // 0 = next edge rising/sample, 1 = next edge falling/advance
    reg [7:0] tx_latched;

    always @* begin
        io_oe = busy ? 4'b0001 : 4'b0000;
        io_out = 4'b0;
        if (busy) io_out[0] = tx_latched[7-bitn];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_byte <= 0;
            busy <= 0;
            done <= 0;
            sck <= 0;
            cs <= 1;
            bitn <= 0;
            divcnt <= 0;
            phase <= 0;
            tx_latched <= 0;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                sck <= 1'b0;
                cs <= 1'b1;
                if (start) begin
                    tx_latched <= tx_byte;
                    rx_byte <= 0;
                    bitn <= 0;
                    divcnt <= HALF_DIV-1;
                    phase <= 0;
                    busy <= 1'b1;
                    cs <= 1'b0;
                end
            end else if (divcnt != 0) begin
                divcnt <= divcnt - 1'b1;
            end else begin
                divcnt <= HALF_DIV-1;
                if (phase == 1'b0) begin
                    // Rising edge: sample MISO for SPI mode 0.
                    sck <= 1'b1;
                    rx_byte[7-bitn] <= io_in[1];
                    phase <= 1'b1;
                end else begin
                    // Falling edge: advance to the next output bit.
                    sck <= 1'b0;
                    phase <= 1'b0;
                    if (bitn == 3'd7) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        cs <= 1'b1;
                    end else begin
                        bitn <= bitn + 1'b1;
                    end
                end
            end
        end
    end
endmodule
