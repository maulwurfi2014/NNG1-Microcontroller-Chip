`timescale 1ns/1ps
module nng1(
 input wire clk,input wire rst_n,input wire ena,
 input wire [7:0] ui_in,output wire [7:0] uo_out,
 input wire [7:0] uio_in,output reg [7:0] uio_out,
 output reg [7:0] uio_oe,
 input wire test_mode,
 input wire [31:0] test_rdata
);
 wire [31:0] ia;
 wire [31:0] id;
 wire [31:0] da;
 wire [31:0] dw;
 wire [31:0] dr;
 wire [31:0] ram_r;
 wire [31:0] gpio_r;
 wire [31:0] uart_r;
 wire [31:0] spi_r;
 wire [31:0] i2c_r;
 wire [31:0] pwm_r;
 wire [31:0] timer_r;
 wire [31:0] wd_r;
 wire [31:0] irqr;
 wire [31:0] qspi_r;
 wire [3:0] dbe;
 wire dwe;

 wire ram_sel;
 wire gpio_sel;
 wire uart_sel;
 wire spi_sel;
 wire i2c_sel;
 wire pwm_sel;
 wire timer_sel;
 wire wd_sel;
 wire qspi_sel;
 wire irq_sel;

 wire [19:0] gin;
 wire [19:0] gout;
 wire [19:0] goe;

 wire uart_tx;
 wire spi_sck;
 wire spi_mosi;
 wire spi_cs;
 wire i2c_scl_oe;
 wire i2c_sda_oe;
 wire spi_irq;
 wire i2c_irq;
 wire timer_irq0;
 wire timer_irq1;
 wire wd_irq;
 wire qspi_irq;
 wire irq_cpu;
 wire [2:0] pad_mode;
 wire pad_sel;
 wire [3:0] qspi_io_oe;
 wire [3:0] qspi_io_out;
 wire qspi_cs;
 wire qspi_sck;
 wire [3:0] qspi_io_in;
 wire [31:0] pad_r;
 wire [3:0] pwm_out;
 wire [7:0] irq_sources;
 wire core_rst_n;

 assign ram_sel   = (da >= 32'h1000_0000) && (da < 32'h1000_2000);
 assign gpio_sel  = (da >= 32'h2000_0000) && (da < 32'h2000_0100);
 assign uart_sel  = (da >= 32'h2000_1000) && (da < 32'h2000_1100);
 assign spi_sel   = (da >= 32'h2000_2000) && (da < 32'h2000_2100);
 assign i2c_sel   = (da >= 32'h2000_3000) && (da < 32'h2000_3100);
 assign pwm_sel   = (da >= 32'h2000_4000) && (da < 32'h2000_4100);
 assign timer_sel = (da >= 32'h2000_5000) && (da < 32'h2000_5100);
 assign wd_sel    = (da >= 32'h2000_6000) && (da < 32'h2000_6100);
 assign qspi_sel  = (da >= 32'h2000_7000) && (da < 32'h2000_7100);
 assign irq_sel   = (da >= 32'h2000_8000) && (da < 32'h2000_8100);

 assign gin = {4'b0000,uio_in,ui_in};
 assign irq_sources = {2'b00,qspi_irq,wd_irq,timer_irq1,timer_irq0,
                       i2c_irq,spi_irq,1'b0};
 assign pad_sel = (da >= 32'h2000_9000) && (da < 32'h2000_9100);

 reset_sync rs(.clk(clk),.arst_n(rst_n),.srst_n(core_rst_n));

 rv32i_core cpu(
  .clk(clk),.rst_n(core_rst_n),.imem_addr(ia),.imem_rdata(id),
  .dmem_addr(da),.dmem_wdata(dw),.dmem_rdata(dr),
  .dmem_we(dwe),.dmem_be(dbe),.irq(irq_cpu)
 );

 wire [31:0] id_rom;
 bootrom rom(.addr(ia[9:2]),.rdata(id_rom));
 assign id = test_mode ? test_rdata : id_rom;

 sram ram(
  .clk(clk),.addr(da[12:2]),.we(dwe && ram_sel),
  .be(dbe),.wdata(dw),.rdata(ram_r)
 );

 gpio gp(
  .clk(clk),.rst_n(core_rst_n),.sel(gpio_sel),.we(dwe),
  .addr(da[5:2]),.wdata(dw),.rdata(gpio_r),
  .gpio_in(gin),.gpio_out(gout),.gpio_oe(goe)
 );

 uart u(
  .clk(clk),.rst_n(core_rst_n),.sel(uart_sel),.we(dwe),
  .addr(da[5:2]),.wdata(dw),.rdata(uart_r),
  .rx((pad_mode == 3'd4) ? uio_in[1] : uio_in[0]),.tx(uart_tx),.irq_rx(),.irq_tx()
 );

 spi_master sp(
  .clk(clk),.rst_n(core_rst_n),.sel(spi_sel),.we(dwe),
  .addr(da[5:2]),.wdata(dw),.rdata(spi_r),
  .sck(spi_sck),.mosi(spi_mosi),.miso((pad_mode == 3'd2) ? uio_in[3] : uio_in[1]),
  .cs(spi_cs),.irq(spi_irq)
 );

 i2c_master ic(
  .clk(clk),.rst_n(core_rst_n),.sel(i2c_sel),.we(dwe),
  .addr(da[5:2]),.wdata(dw),.rdata(i2c_r),
  .scl_oe(i2c_scl_oe),.sda_oe(i2c_sda_oe),
  .sda_in((pad_mode == 3'd3) ? uio_in[1] : uio_in[2]),.busy(),.irq(i2c_irq)
 );

 pwm pw(
  .clk(clk),.rst_n(core_rst_n),.sel(pwm_sel),.we(dwe),
  .addr(da[7:2]),.wdata(dw),.rdata(pwm_r),.pwm_out(pwm_out)
 );

 timer ti(
  .clk(clk),.rst_n(core_rst_n),.sel(timer_sel),.we(dwe),
  .addr(da[5:2]),.wdata(dw),.rdata(timer_r),
  .irq0(timer_irq0),.irq1(timer_irq1)
 );

 watchdog wd(
  .clk(clk),.rst_n(core_rst_n),.sel(wd_sel),.we(dwe),
  .addr(da[5:2]),.wdata(dw),.rdata(wd_r),
  .irq(wd_irq),.reset_req()
 );

 irq_controller ir(
  .clk(clk),.rst_n(core_rst_n),.sel(irq_sel),.we(dwe),
  .addr(da[5:2]),.wdata(dw),.rdata(irqr),
  .irq_sources(irq_sources),.irq(irq_cpu)
 );

 qspi_master q(
  .clk(clk),.rst_n(core_rst_n),.sel(qspi_sel),.we(dwe),
  .addr(da[6:2]),.wdata(dw),.rdata(qspi_r),
  .cs(qspi_cs),.sck(qspi_sck),.io_oe(qspi_io_oe),.io_in(qspi_io_in),
  .io_out(qspi_io_out),.busy(),.irq(qspi_irq)
 );

 pad_ctrl pc(
  .clk(clk),.rst_n(core_rst_n),.sel(pad_sel),.we(dwe),
  .addr(da[5:2]),.wdata(dw),.rdata(pad_r),.mode(pad_mode)
 );

 assign dr = ram_sel  ? ram_r  :
             gpio_sel ? gpio_r :
             uart_sel ? uart_r :
             spi_sel  ? spi_r  :
             i2c_sel  ? i2c_r  :
             pwm_sel  ? pwm_r  :
             timer_sel? timer_r:
             wd_sel   ? wd_r   :
             irq_sel  ? irqr   :
             qspi_sel ? qspi_r :
             pad_sel  ? pad_r  : 32'b0;

 assign uo_out = gout[7:0];

 assign qspi_io_in = uio_in[3:0];

 always @* begin
  uio_out = 8'b0;
  uio_oe  = 8'b0;
  case(pad_mode)
   3'd0: begin // GPIO bank
    uio_out = gout[15:8];
    uio_oe  = goe[15:8];
   end
   3'd1: begin // QSPI
    uio_out[3:0] = qspi_io_out;
    uio_out[4]   = qspi_cs;
    uio_out[5]   = qspi_sck;
    uio_oe[3:0]  = qspi_io_oe;
    uio_oe[4]    = 1'b1;
    uio_oe[5]    = 1'b1;
   end
   3'd2: begin // SPI: MOSI/SCK/CS/MISO
    uio_out[0] = spi_mosi;
    uio_out[1] = spi_sck;
    uio_out[2] = spi_cs;
    uio_oe[0]  = 1'b1;
    uio_oe[1]  = 1'b1;
    uio_oe[2]  = 1'b1;
   end
   3'd3: begin // I2C open-drain: SCL/SDA
    uio_out[0] = 1'b0;
    uio_out[1] = 1'b0;
    uio_oe[0]  = i2c_scl_oe;
    uio_oe[1]  = i2c_sda_oe;
   end
   3'd4: begin // UART: TX/RX
    uio_out[0] = uart_tx;
    uio_oe[0]  = 1'b1;
   end
   default: begin
    uio_out = gout[15:8];
    uio_oe  = goe[15:8];
   end
  endcase
 end

endmodule
