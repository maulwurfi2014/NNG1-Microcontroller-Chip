`timescale 1ns/1ps
module nng1_boot_uart_phy #(
    parameter integer CLK_HZ = 10_000_000,
    parameter integer BAUD = 115200
)(
    input wire clk,
    input wire rst_n,
    input wire rx,
    output reg tx,
    output reg [7:0] rx_data,
    output reg rx_valid,
    input wire tx_start,
    input wire [7:0] tx_data,
    output reg tx_busy,
    output reg tx_done
);
    localparam integer DIV = (CLK_HZ / BAUD < 1) ? 1 : (CLK_HZ / BAUD);
    localparam integer HALF = (DIV / 2 < 1) ? 1 : (DIV / 2);

    localparam RX_IDLE=2'd0, RX_START=2'd1, RX_DATA=2'd2, RX_STOP=2'd3;
    localparam TX_IDLE=2'd0, TX_DATA=2'd1, TX_STOP=2'd2;
    reg [1:0] rx_state, tx_state;
    reg [15:0] rx_cnt, tx_cnt;
    reg [2:0] rx_bit, tx_bit;
    reg [7:0] rx_shift, tx_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            rx_cnt <= 0;
            rx_bit <= 0;
            rx_shift <= 0;
            rx_data <= 0;
            rx_valid <= 0;
        end else begin
            rx_valid <= 1'b0;
            case (rx_state)
                RX_IDLE: if (!rx) begin rx_cnt <= HALF-1; rx_state <= RX_START; end
                RX_START: begin
                    if (rx_cnt != 0) rx_cnt <= rx_cnt - 1'b1;
                    else if (!rx) begin rx_cnt <= DIV-1; rx_bit <= 0; rx_state <= RX_DATA; end
                    else rx_state <= RX_IDLE;
                end
                RX_DATA: begin
                    if (rx_cnt != 0) rx_cnt <= rx_cnt - 1'b1;
                    else begin
                        rx_shift[rx_bit] <= rx;
                        rx_cnt <= DIV-1;
                        if (rx_bit == 3'd7) rx_state <= RX_STOP;
                        else rx_bit <= rx_bit + 1'b1;
                    end
                end
                RX_STOP: begin
                    if (rx_cnt != 0) rx_cnt <= rx_cnt - 1'b1;
                    else begin
                        rx_data <= rx_shift;
                        rx_valid <= 1'b1;
                        rx_state <= RX_IDLE;
                    end
                end
                default: rx_state <= RX_IDLE;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_cnt <= 0;
            tx_bit <= 0;
            tx_shift <= 0;
            tx <= 1'b1;
            tx_busy <= 1'b0;
            tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0;
            case (tx_state)
                TX_IDLE: begin
                    tx <= 1'b1;
                    if (tx_start && !tx_busy) begin
                        tx_shift <= tx_data;
                        tx_busy <= 1'b1;
                        tx_bit <= 0;
                        tx_cnt <= DIV-1;
                        tx <= 1'b0;
                        tx_state <= TX_DATA;
                    end
                end
                TX_DATA: begin
                    if (tx_cnt != 0) tx_cnt <= tx_cnt - 1'b1;
                    else begin
                        tx <= tx_shift[tx_bit];
                        tx_cnt <= DIV-1;
                        if (tx_bit == 3'd7) tx_state <= TX_STOP;
                        else tx_bit <= tx_bit + 1'b1;
                    end
                end
                TX_STOP: begin
                    if (tx_cnt != 0) tx_cnt <= tx_cnt - 1'b1;
                    else begin
                        tx <= 1'b1;
                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;
                        tx_state <= TX_IDLE;
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end
endmodule
