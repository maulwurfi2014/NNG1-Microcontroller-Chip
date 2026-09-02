`timescale 1ns/1ps
module nng1_bootloader #(
    parameter integer CLK_HZ = 10_000_000,
    parameter integer UART_BAUD = 115200,
    parameter integer QSPI_HALF_DIV = 4,
    parameter integer MAX_IMAGE_BYTES = 8192
)(
    input wire clk,
    input wire rst_n,
    input wire boot_mode,
    input wire uart_rx,
    output wire uart_tx,
    input wire [3:0] qspi_io_in,
    output wire qspi_cs,
    output wire qspi_sck,
    output wire [3:0] qspi_io_oe,
    output wire [3:0] qspi_io_out,
    output reg sram_we,
    output reg [10:0] sram_addr,
    output reg [31:0] sram_wdata,
    output reg [3:0] sram_be,
    output reg boot_done,
    output reg active,
    output reg [7:0] status
);
    localparam [7:0] M0=8'h4E, M1=8'h4E, M2=8'h47, M3=8'h31;

    wire [7:0] urx_data;
    wire urx_valid;
    reg utx_start;
    reg [7:0] utx_data;
    wire utx_busy, utx_done;
    nng1_boot_uart_phy #(.CLK_HZ(CLK_HZ),.BAUD(UART_BAUD)) uart_phy(
        .clk(clk),.rst_n(rst_n),.rx(uart_rx),.tx(uart_tx),
        .rx_data(urx_data),.rx_valid(urx_valid),
        .tx_start(utx_start),.tx_data(utx_data),.tx_busy(utx_busy),.tx_done(utx_done)
    );

    reg qbyte_start;
    reg [7:0] qbyte_tx;
    wire [7:0] qbyte_rx;
    wire qbyte_busy, qbyte_done;
    wire qbyte_sck, qbyte_cs_unused;
    wire [3:0] qbyte_oe, qbyte_out;
    nng1_qspi_byte_phy #(.HALF_DIV(QSPI_HALF_DIV)) qphy(
        .clk(clk),.rst_n(rst_n),.start(qbyte_start),.tx_byte(qbyte_tx),.rx_byte(qbyte_rx),
        .busy(qbyte_busy),.done(qbyte_done),.sck(qbyte_sck),.cs(qbyte_cs_unused),
        .io_oe(qbyte_oe),.io_out(qbyte_out),.io_in(qspi_io_in)
    );

    // UART states.
    localparam U_READY=8'd0,U_M0=8'd1,U_M1=8'd2,U_M2=8'd3,U_M3=8'd4,
               U_L0=8'd5,U_L1=8'd6,U_L2=8'd7,U_L3=8'd8,U_DATA=8'd9,
               U_C0=8'd10,U_C1=8'd11,U_C2=8'd12,U_C3=8'd13,U_ACK=8'd14,
               U_RESTART=8'd15;
    // QSPI states.
    localparam Q_CMD=8'd32,Q_A0=8'd33,Q_A1=8'd34,Q_A2=8'd35,Q_M0=8'd36,
               Q_M1=8'd37,Q_M2=8'd38,Q_M3=8'd39,Q_L0=8'd40,Q_L1=8'd41,
               Q_L2=8'd42,Q_L3=8'd43,Q_DATA=8'd44,Q_C0=8'd45,Q_C1=8'd46,
               Q_C2=8'd47,Q_C3=8'd48,DONE=8'd60,ERROR=8'd61;

    reg [7:0] state;
    reg [31:0] image_len, image_pos, crc_reg, received_crc;

    // Keep flash CS_N asserted across the whole 0x03 command + address + data transaction.
    assign qspi_cs = (!boot_mode && state >= Q_CMD && state <= Q_C3) ? 1'b0 : 1'b1;
    assign qspi_sck = qbyte_sck;
    assign qspi_io_oe = qbyte_oe;
    assign qspi_io_out = qbyte_out;

    function [31:0] crc32_byte;
        input [31:0] crc_in;
        input [7:0] data;
        integer k;
        reg [31:0] c;
        begin
            c = crc_in ^ {24'b0,data};
            for (k=0;k<8;k=k+1)
                if (c[0]) c=(c>>1)^32'hEDB88320; else c=c>>1;
            crc32_byte = c;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= boot_mode ? U_READY : Q_CMD;
            image_len <= 0;
            image_pos <= 0;
            crc_reg <= 32'hFFFF_FFFF;
            received_crc <= 0;
            utx_start <= 0;
            utx_data <= 0;
            qbyte_start <= 0;
            qbyte_tx <= 0;
            sram_we <= 0;
            sram_addr <= 0;
            sram_wdata <= 0;
            sram_be <= 0;
            boot_done <= 0;
            active <= 1;
            status <= boot_mode ? 8'h52 : 8'h51;
        end else begin
            sram_we <= 0;
            utx_start <= 0;
            qbyte_start <= 0;

            case (state)
                U_READY: begin
                    active <= 1; boot_done <= 0; status <= 8'h52;
                    if (!utx_busy && !utx_start) begin
                        utx_data <= 8'h52; utx_start <= 1; state <= U_M0;
                    end
                end
                U_M0: if (urx_valid) state <= (urx_data==M0) ? U_M1 : U_M0;
                U_M1: if (urx_valid) state <= (urx_data==M1) ? U_M2 : U_M0;
                U_M2: if (urx_valid) state <= (urx_data==M2) ? U_M3 : U_M0;
                U_M3: if (urx_valid) state <= (urx_data==M3) ? U_L0 : U_M0;
                U_L0: if (urx_valid) begin image_len[7:0]<=urx_data;state<=U_L1;end
                U_L1: if (urx_valid) begin image_len[15:8]<=urx_data;state<=U_L2;end
                U_L2: if (urx_valid) begin image_len[23:16]<=urx_data;state<=U_L3;end
                U_L3: if (urx_valid) begin
                    image_len[31:24]<=urx_data;
                    if ({urx_data,image_len[23:0]} != 0 && {urx_data,image_len[23:0]} <= MAX_IMAGE_BYTES) begin
                        image_pos<=0; crc_reg<=32'hFFFF_FFFF; status<=8'h44; state<=U_DATA;
                    end else begin
                        utx_data<=8'h4C; utx_start<=1; state<=U_RESTART;
                    end
                end
                U_DATA: if (urx_valid) begin
                    sram_addr<=image_pos[12:2];
                    sram_be<=4'b0001<<image_pos[1:0];
                    sram_wdata<=({24'b0,urx_data}<<(8*image_pos[1:0]));
                    sram_we<=1;
                    crc_reg<=crc32_byte(crc_reg,urx_data);
                    if (image_pos+1 >= image_len) begin image_pos<=0; received_crc<=0; state<=U_C0; end
                    else image_pos<=image_pos+1;
                end
                U_C0: if (urx_valid) begin received_crc[7:0]<=urx_data;state<=U_C1;end
                U_C1: if (urx_valid) begin received_crc[15:8]<=urx_data;state<=U_C2;end
                U_C2: if (urx_valid) begin received_crc[23:16]<=urx_data;state<=U_C3;end
                U_C3: if (urx_valid) begin
                    received_crc[31:24]<=urx_data;
                    if ({urx_data,received_crc[23:0]} == ~crc_reg) begin
                        utx_data<=8'h4F; utx_start<=1; status<=8'h4F; state<=U_ACK;
                    end else begin
                        utx_data<=8'h43; utx_start<=1; status<=8'h43; state<=U_RESTART;
                    end
                end
                U_ACK: if (utx_done) begin boot_done<=1;active<=0;status<=8'h4F;state<=DONE;end
                U_RESTART: if (utx_done) begin status<=8'h52;state<=U_M0;end

                Q_CMD: begin
                    active<=1;boot_done<=0;status<=8'h51;
                    if(!qbyte_busy)begin qbyte_tx<=8'h03;qbyte_start<=1;state<=Q_A0;end
                end
                Q_A0: if(qbyte_done)begin qbyte_tx<=0;qbyte_start<=1;state<=Q_A1;end
                Q_A1: if(qbyte_done)begin qbyte_tx<=0;qbyte_start<=1;state<=Q_A2;end
                Q_A2: if(qbyte_done)begin qbyte_tx<=0;qbyte_start<=1;state<=Q_M0;end
                Q_M0: if(qbyte_done)begin qbyte_tx<=0;qbyte_start<=1;state<=qbyte_rx==M0?Q_M1:ERROR;end
                Q_M1: if(qbyte_done)begin qbyte_tx<=0;qbyte_start<=1;state<=qbyte_rx==M1?Q_M2:ERROR;end
                Q_M2: if(qbyte_done)begin qbyte_tx<=0;qbyte_start<=1;state<=qbyte_rx==M2?Q_M3:ERROR;end
                Q_M3: if(qbyte_done)begin qbyte_tx<=0;qbyte_start<=1;state<=qbyte_rx==M3?Q_L0:ERROR;end
                Q_L0: if(qbyte_done)begin image_len[7:0]<=qbyte_rx;qbyte_tx<=0;qbyte_start<=1;state<=Q_L1;end
                Q_L1: if(qbyte_done)begin image_len[15:8]<=qbyte_rx;qbyte_tx<=0;qbyte_start<=1;state<=Q_L2;end
                Q_L2: if(qbyte_done)begin image_len[23:16]<=qbyte_rx;qbyte_tx<=0;qbyte_start<=1;state<=Q_L3;end
                Q_L3: if(qbyte_done)begin
                    image_len[31:24]<=qbyte_rx;
                    if({qbyte_rx,image_len[23:0]} != 0 && {qbyte_rx,image_len[23:0]} <= MAX_IMAGE_BYTES)begin
                        image_pos<=0;crc_reg<=32'hFFFF_FFFF;qbyte_tx<=0;qbyte_start<=1;state<=Q_DATA;
                    end else state<=ERROR;
                end
                Q_DATA: if(qbyte_done)begin
                    sram_addr<=image_pos[12:2];sram_be<=4'b0001<<image_pos[1:0];sram_wdata<=({24'b0,qbyte_rx}<<(8*image_pos[1:0]));sram_we<=1;
                    crc_reg<=crc32_byte(crc_reg,qbyte_rx);
                    if(image_pos+1>=image_len)begin image_pos<=0;received_crc<=0;qbyte_tx<=0;qbyte_start<=1;state<=Q_C0;end
                    else begin image_pos<=image_pos+1;qbyte_tx<=0;qbyte_start<=1;end
                end
                Q_C0: if(qbyte_done)begin received_crc[7:0]<=qbyte_rx;qbyte_tx<=0;qbyte_start<=1;state<=Q_C1;end
                Q_C1: if(qbyte_done)begin received_crc[15:8]<=qbyte_rx;qbyte_tx<=0;qbyte_start<=1;state<=Q_C2;end
                Q_C2: if(qbyte_done)begin received_crc[23:16]<=qbyte_rx;qbyte_tx<=0;qbyte_start<=1;state<=Q_C3;end
                Q_C3: if(qbyte_done)begin
                    received_crc[31:24]<=qbyte_rx;
                    if({qbyte_rx,received_crc[23:0]} == ~crc_reg)begin boot_done<=1;active<=0;status<=8'h4F;state<=DONE;end else state<=ERROR;
                end
                DONE: begin boot_done<=1;active<=0;status<=8'h4F;end
                ERROR: begin boot_done<=0;active<=0;status<=8'h45;end
                default: state <= boot_mode ? U_READY : Q_CMD;
            endcase
        end
    end
endmodule
