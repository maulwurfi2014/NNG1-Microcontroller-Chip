`timescale 1ns/1ps
module nng1(
 input wire clk, input wire rst_n, input wire ena,
 input wire [7:0] ui_in, output wire [7:0] uo_out,
 input wire [7:0] uio_in, output reg [7:0] uio_out,
 output reg [7:0] uio_oe,
 input wire test_mode,
 input wire [31:0] test_rdata
);
 wire [31:0] ia, id, da, dw, dr;
 wire [31:0] ram_r, ram_i_r, gpio_r, uart_r, spi_r, i2c_r, pwm_r, timer_r, wd_r, irqr, qspi_r;
 wire [3:0] dbe;
 wire dwe;
 wire ram_sel, gpio_sel, uart_sel, spi_sel, i2c_sel, pwm_sel, timer_sel, wd_sel, qspi_sel, irq_sel;
 wire [19:0] gin, gout, goe;
 wire uart_tx, boot_uart_tx;
 wire spi_sck, spi_mosi, spi_cs, i2c_scl_oe, i2c_sda_oe;
 wire spi_irq, i2c_irq, timer_irq0, timer_irq1, wd_irq, qspi_irq, irq_cpu;
 wire [3:0] qspi_io_oe, qspi_io_out, qspi_io_in;
 wire qspi_cs, qspi_sck;
 wire [3:0] boot_qspi_io_oe, boot_qspi_io_out;
 wire boot_qspi_cs, boot_qspi_sck;
 wire boot_sram_we;
 wire [10:0] boot_sram_addr;
 wire [31:0] boot_sram_wdata;
 wire [3:0] boot_sram_be;
 wire boot_done_int, boot_active;
 wire [7:0] boot_status;
 wire core_rst_n;
 wire core_reset_n;
 wire [31:0] cpu_reset_pc;
 wire boot_mode = ui_in[1];

 // Dedicated external pins:
 // ui_in[0] = UART_RX
 // ui_in[1] = BOOT (1=UART boot, 0=QSPI flash boot)
 // ui_in[7:2] = GPIO_IN0..GPIO_IN5
 // uo_out[0] = UART_TX
 // uo_out[7:1] = GPIO_OUT0..GPIO_OUT6
 // uio[0] = QSPI_IO0 / MOSI
 // uio[1] = QSPI_IO1 / MISO
 // uio[2] = QSPI_IO2
 // uio[3] = QSPI_IO3
 // uio[4] = QSPI_CS_N
 // uio[5] = QSPI_SCK
 // uio[6] = GPIO7
 // uio[7] = GPIO8

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

 // 8 GPIO inputs: 6 dedicated UI pins + 2 GPIO bidir pins.
 assign gin = {12'b0, uio_in[7:6], ui_in[7:2]};

 // Interrupt source ordering preserved for the existing peripheral map.
 wire [7:0] irq_sources = {2'b00,qspi_irq,wd_irq,timer_irq1,timer_irq0,i2c_irq,spi_irq};
 assign qspi_io_in = uio_in[3:0];

 reset_sync rs(.clk(clk), .arst_n(rst_n), .srst_n(core_rst_n));

 nng1_bootloader boot(
   .clk(clk), .rst_n(core_rst_n), .boot_mode(boot_mode),
   .uart_rx(ui_in[0]), .uart_tx(boot_uart_tx),
   .qspi_cs(boot_qspi_cs), .qspi_sck(boot_qspi_sck),
   .qspi_io_oe(boot_qspi_io_oe), .qspi_io_out(boot_qspi_io_out), .qspi_io_in(qspi_io_in),
   .sram_we(boot_sram_we), .sram_addr(boot_sram_addr), .sram_wdata(boot_sram_wdata), .sram_be(boot_sram_be),
   .boot_done(boot_done_int), .active(boot_active), .status(boot_status)
 );

 assign cpu_reset_pc = test_mode ? 32'h0000_0000 : 32'h1000_0000;
 assign core_reset_n = core_rst_n & (test_mode | boot_done_int);

 rv32i_core cpu(
  .clk(clk), .rst_n(core_reset_n), .reset_pc(cpu_reset_pc),
  .imem_addr(ia), .imem_rdata(id),
  .dmem_addr(da), .dmem_wdata(dw), .dmem_rdata(dr),
  .dmem_we(dwe), .dmem_be(dbe), .irq(irq_cpu)
 );

 wire [31:0] id_rom;
 bootrom rom(.addr(ia[9:2]), .rdata(id_rom));
 assign id = test_mode ? test_rdata :
             ((ia >= 32'h1000_0000) && (ia < 32'h1000_2000) ? ram_i_r : id_rom);

 sram ram(
  .clk(clk), .addr(boot_sram_we ? boot_sram_addr : da[12:2]),
  .we(boot_sram_we ? 1'b1 : (dwe && ram_sel)),
  .be(boot_sram_we ? boot_sram_be : dbe),
  .wdata(boot_sram_we ? boot_sram_wdata : dw), .rdata(ram_r),
  .iaddr(ia[12:2]), .irdata(ram_i_r)
 );

 gpio gp(
  .clk(clk), .rst_n(core_rst_n), .sel(gpio_sel), .we(dwe),
  .addr(da[5:2]), .wdata(dw), .rdata(gpio_r),
  .gpio_in(gin), .gpio_out(gout), .gpio_oe(goe)
 );

 uart u(
  .clk(clk), .rst_n(core_rst_n), .sel(uart_sel), .we(dwe),
  .addr(da[5:2]), .wdata(dw), .rdata(uart_r),
  .rx(ui_in[0]), .tx(uart_tx), .irq_rx(), .irq_tx()
 );

 spi_master sp(
  .clk(clk), .rst_n(core_rst_n), .sel(spi_sel), .we(dwe),
  .addr(da[5:2]), .wdata(dw), .rdata(spi_r),
  .sck(spi_sck), .mosi(spi_mosi), .miso(1'b0), .cs(spi_cs), .irq(spi_irq)
 );

 i2c_master ic(
  .clk(clk), .rst_n(core_rst_n), .sel(i2c_sel), .we(dwe),
  .addr(da[5:2]), .wdata(dw), .rdata(i2c_r),
  .scl_oe(i2c_scl_oe), .sda_oe(i2c_sda_oe), .sda_in(1'b1), .busy(), .irq(i2c_irq)
 );

 pwm pw(
  .clk(clk), .rst_n(core_rst_n), .sel(pwm_sel), .we(dwe),
  .addr(da[7:2]), .wdata(dw), .rdata(pwm_r), .pwm_out()
 );

 timer ti(
  .clk(clk), .rst_n(core_rst_n), .sel(timer_sel), .we(dwe),
  .addr(da[5:2]), .wdata(dw), .rdata(timer_r), .irq0(timer_irq0), .irq1(timer_irq1)
 );

 watchdog wd(
  .clk(clk), .rst_n(core_rst_n), .sel(wd_sel), .we(dwe),
  .addr(da[5:2]), .wdata(dw), .rdata(wd_r), .irq(wd_irq), .reset_req()
 );

 irq_controller ir(
  .clk(clk), .rst_n(core_rst_n), .sel(irq_sel), .we(dwe),
  .addr(da[5:2]), .wdata(dw), .rdata(irqr), .irq_sources(irq_sources), .irq(irq_cpu)
 );

 qspi_master q(
  .clk(clk), .rst_n(core_rst_n), .sel(qspi_sel), .we(dwe),
  .addr(da[6:2]), .wdata(dw), .rdata(qspi_r),
  .cs(qspi_cs), .sck(qspi_sck), .io_oe(qspi_io_oe), .io_in(qspi_io_in),
  .io_out(qspi_io_out), .busy(), .irq(qspi_irq)
 );

 assign dr = ram_sel   ? ram_r  :
             gpio_sel  ? gpio_r :
             uart_sel  ? uart_r :
             spi_sel   ? spi_r  :
             i2c_sel   ? i2c_r  :
             pwm_sel   ? pwm_r  :
             timer_sel ? timer_r:
             wd_sel    ? wd_r   :
             irq_sel   ? irqr   :
             qspi_sel  ? qspi_r : 32'b0;

 // UART is permanently on uo_out[0]. During boot the ROM bootloader owns TX;
 // after boot the CPU UART peripheral owns TX.
 assign uo_out[0] = boot_active ? boot_uart_tx : uart_tx;
 assign uo_out[7:1] = gout[6:0];

 always @* begin
   uio_out = 8'b0;
   uio_oe  = 8'b0;

   // Dedicated QSPI pins [0:5].
   if (boot_active && !boot_mode) begin
     uio_out[3:0] = boot_qspi_io_out;
     uio_out[4]   = boot_qspi_cs;
     uio_out[5]   = boot_qspi_sck;
     uio_oe[3:0]  = boot_qspi_io_oe;
     uio_oe[4]    = 1'b1;
     uio_oe[5]    = 1'b1;
   end else begin
     uio_out[3:0] = qspi_io_out;
     uio_out[4]   = qspi_cs;
     uio_out[5]   = qspi_sck;
     uio_oe[3:0]  = qspi_io_oe;
     uio_oe[4]    = 1'b1;
     uio_oe[5]    = 1'b1;
   end

   // GPIO bidirectional pins [6:7].
   uio_out[6] = gout[7];
   uio_out[7] = gout[8];
   uio_oe[6]  = goe[7];
   uio_oe[7]  = goe[8];
 end
endmodule
