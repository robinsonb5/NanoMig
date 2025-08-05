// nanomig simulation top

module nanomig_tb
  (
   input     clk_85,
   input	 clk, // 28mhz
   output	 clk_7m, 
   output	 clk7_en,
   output	 clk7n_en,
   input	 reset,

   // serial output, mainly for diagrom
   output	 uart_tx,

   // signal to e.g. trigger on disk activity
   output	 pwr_led,
   output	 fdd_led,
   output	 hdd_led,
   input	 trigger, 
   
   input [5:0]    chipset_config,
   
   // video
   output	 hs_n,
   output	 vs_n,
   output [3:0]	 red,
   output [3:0]	 green,
   output [3:0]	 blue,

   input [7:0]	 sdc_img_mounted,
   input [31:0]	 sdc_img_size,

`ifdef SD_EMU   
   output	 sdclk,
   output	 sdcmd,
   input	 sdcmd_in,
   output [3:0]	 sddat,
   input [3:0]	 sddat_in,
`else
   output [7:0]	 sdc_rd,
   output [7:0]  sdc_wr,
   output [31:0] sdc_sector,
   input	 sdc_busy,
   input	 sdc_done,
   input	 sdc_byte_in_strobe,
   input [8:0]	 sdc_byte_addr,
   input [7:0]	 sdc_byte_in_data,
   output [7:0]  sdc_byte_out_data,
`endif // !`ifdef SD_EMU
   
   // external ram/rom interface
   output [15:0] ram_data, // sram data bus
   input [15:0]	 ramdata_in, // sram data bus in
   output [23:1] ram_address, // sram address bus
   output	 _ram_bhe, // sram upper byte select
   output	 _ram_ble, // sram lower byte select
   output	 _ram_we, // sram write enable
   output	 _ram_oe      // sram output enable
   );
   
`ifdef SD_EMU
// for floppy IO the SD card itself may be included into the simulation or not
wire [7:0]	 sdc_rd;
wire [7:0]	 sdc_wr;
wire [31:0]	 sdc_sector;
wire		 sdc_busy;
wire		 sdc_done;
wire		 sdc_byte_in_strobe;
wire [8:0]	 sdc_byte_addr;
wire [7:0]	 sdc_byte_in_data;
wire [7:0]	 sdc_byte_out_data;

sd_rw #(
    .CLK_DIV(3'd0),                // for 28 Mhz clock
    .SIMULATE(1'b1)
) sd_card (
    .rstn(!reset),                 // rstn active-low, 1:working, 0:reset
    .clk(clk),                     // clock

    // SD card signals
    .sdclk(sdclk),
    .sdcmd(sdcmd),
    .sdcmd_in(sdcmd_in),
    .sddat(sddat),
    .sddat_in(sddat_in),

    // user read sector command interface (sync with clk)
    .rstart(sdc_rd), 
    .wstart(sdc_wr), 
    .sector(sdc_sector),
    .rbusy(sdc_busy),
    .rdone(sdc_done),
                 
    // sector data output interface (sync with clk)
    .inbyte(sdc_byte_out_data),
    .outen(sdc_byte_in_strobe),  // when outen=1, a byte of sector content is read out from outbyte
    .outaddr(sdc_byte_addr),  // outaddr from 0 to 511, because the sector size is 512
    .outbyte(sdc_byte_in_data)   // a byte of sector content
);
`endif //  `ifdef SD_EMU
   
wire fastram_sel;
wire [22:1] fastram_addr;
wire fastram_lds;
wire fastram_uds;
wire [15:0] fastram_dout;
wire [15:0] fastram_din;
wire [1:0] fastram_be;
wire fastram_wr;
reg fastram_ready;

nanomig nanomig (
		 // system pins
		 .clk_sys(clk),   // 28.37516 MHz clock
		 .reset(reset),
		 .clk7_en(clk7_en),
		 .clk7n_en(clk7n_en),

		 .pwr_led(pwr_led),
		 .fdd_led(fdd_led),
		 .hdd_led(hdd_led),

                 .chipset_config(chipset_config),
                 .memory_config(8'b0_0_00_00_01),
                 .floppy_config(4'h0),
                 .ide_config(6'b100111), // Disable fast IDE mode for now, since it's not yet implemented for Nanomig

		 .hs(hs_n),
		 .vs(vs_n),
		 .r(red),
		 .g(green),
		 .b(blue),

		 .joystick0(6'b000000),
 		 .joystick1(6'b000000),

		 // sd card interface for floppy disk emulation
		 .sdc_img_mounted    ( sdc_img_mounted     ),
		 .sdc_img_size       ( sdc_img_size        ),  // length of image file		 
		 .sdc_rd(sdc_rd),
		 .sdc_wr(sdc_wr),
		 .sdc_sector(sdc_sector),
		 .sdc_busy(sdc_busy),
		 .sdc_done(sdc_done),
		 .sdc_byte_in_strobe(sdc_byte_in_strobe),
		 .sdc_byte_addr(sdc_byte_addr),
		 .sdc_byte_in_data(sdc_byte_in_data),
		 .sdc_byte_out_data(sdc_byte_out_data),
		 
		 .uart_tx(uart_tx),
		 
		 // (s(d))ram interface
		 .ram_data(ram_data),       // sram data bus
		 .ramdata_in(ramdata_in),   // sram data bus in
		 .chip48(48'h0),            // big chip read, needed for AGA only
		 .ram_address(ram_address), // sram address bus
		 ._ram_bhe(_ram_bhe),       // sram upper byte select
		 ._ram_ble(_ram_ble),       // sram lower byte select
		 ._ram_we(_ram_we),         // sram write enable
		 ._ram_oe(_ram_oe),          // sram output enable

		 .fastram_sel(fastram_sel),
		 .fastram_addr(fastram_addr),
		 .fastram_lds(fastram_lds),
		 .fastram_uds(fastram_uds),
		 .fastram_dout(fastram_dout),
		 .fastram_din(fastram_din),
		 .fastram_wr(fastram_wr),
		 .fastram_ready(fastram_ready)

);

// run a counter at 28Mhz synchonous to the 7Mhz bus cycle
reg	    [1:0] cyc;   
always @(posedge clk)
  if(clk7_en) cyc <= 2'd0;
  else        cyc <= cyc + 2'd1;

wire        sdram_ready;
wire	    sdram_rw      = 1'b1;
   
wire		sdram_cs      = 1'b0;

wire        sdram_sync    = cyc;
   
wire		sdram_refresh = 1'b0;
   
wire [21:0] sdram_addr    = 22'b0;
wire [15:0] sdram_din     = 16'b0;
wire [1:0]  sdram_be      = 2'b11;
wire		sdram_we      = 1'b0;
   
wire O_sdram_cke;
wire [31:0] IO_sdram_dq;
wire [11:0] O_sdram_addr;
wire [3:0] O_sdram_dqm;
wire [1:0] O_sdram_ba;
wire O_sdram_cs_n;
wire O_sdram_wen_n;
wire O_sdram_ras_n;
wire O_sdram_cas_n;

lfsr #(.width(32)) rnd
(
	.clk(clk_85),
	.reset_n(sdram_ready),
	.e(1'b1),
	.save(1'b0),
	.restore(1'b0)
//	.q(IO_sdram_dq)
);


sdram sdram (
//  	.sd_clk     ( O_sdram_clk   ), // sd clock
	.sd_cke     ( O_sdram_cke   ), // clock enable
	.sd_data    ( IO_sdram_dq   ), // 32 bit bidirectional data bus
	.sd_addr    ( O_sdram_addr  ), // 11 bit multiplexed address bus
	.sd_dqm     ( O_sdram_dqm   ), // two byte masks
	.sd_ba      ( O_sdram_ba    ), // two banks
	.sd_cs      ( O_sdram_cs_n  ), // a single chip select
	.sd_we      ( O_sdram_wen_n ), // write enable
	.sd_ras     ( O_sdram_ras_n ), // row address select
	.sd_cas     ( O_sdram_cas_n ), // columns address select

	// cpu/chipset interface
	.clk        ( clk_85       ), // sdram is accessed at 71MHz
	.reset_n    ( !reset       ), // init signal after FPGA config to initialize RAM

	.ready      ( sdram_ready   ), // ram is ready and has been initialized
	.sync       ( sdram_sync    ), // rising edge of sync is begin of a memory cycle
	.refresh    ( sdram_refresh ), // refresh cycle

	.din        ( sdram_din     ), // data input from chipset/cpu
	.dout       ( sdram_dout    ),
	.addr       ( sdram_addr    ), // 22 bit word address
	.ds         ( sdram_be      ), // upper/lower data strobe
	.cs         ( sdram_cs      ), // cpu/chipset requests read/wrie
	.we         ( sdram_we      ), // cpu/chipset requests write

	.p2_din        ( fastram_din     ), // data input from chipset/cpu
	.p2_dout       ( fastram_dout    ),
	.p2_addr       ( fastram_addr    ), // 22 bit word address
	.p2_ds         ( fastram_be      ), // upper/lower data strobe
	.p2_cs         ( fastram_sel     ), // cpu/chipset requests read/wrie
	.p2_we         ( fastram_wr      ),  // cpu/chipset requests write
	.p2_ack        ( fastram_ready   )
);

wire O_sdram_clk = ~clk_85;

// SDRAM 1 - low 16 bits
mt48lc16m16a2
sdram1 (
  .Dq         (IO_sdram_dq[15:0]),
  .Addr       (O_sdram_addr),
  .Ba         (O_sdram_ba),
  .Clk        (O_sdram_clk),
  .Cke        (O_sdram_cke),
  .Cs_n       (O_sdram_cs_n),
  .Ras_n      (O_sdram_ras_n),
  .Cas_n      (O_sdram_cas_n),
  .We_n       (O_sdram_wen_n),
  .Dqm        (O_sdram_dqm[1:0])
);

// SDRAM 2 - high 16 bits
mt48lc16m16a2
sdram2 (
  .Dq         (IO_sdram_dq[31:16]),
  .Addr       (O_sdram_addr),
  .Ba         (O_sdram_ba),
  .Clk        (O_sdram_clk),
  .Cke        (O_sdram_cke),
  .Cs_n       (O_sdram_cs_n),
  .Ras_n      (O_sdram_ras_n),
  .Cas_n      (O_sdram_cas_n),
  .We_n       (O_sdram_wen_n),
  .Dqm        (O_sdram_dqm[3:2])
);


video_analyzer video_analyzer 
(
 .clk(clk),
 .hs(hs_n),
 .vs(vs_n),
 .pal(),
 .interlace(),
 .vreset()
 );   

endmodule
