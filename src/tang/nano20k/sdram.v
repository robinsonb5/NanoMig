//
// sdram.v
//
// sdram controller implementation for the Tang Nano 20k
// 
// Copyright (c) 2023 Till Harbaum <till@harbaum.org> 
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module sdram (

	output		  sd_clk, // sd clock
	output		  sd_cke, // clock enable
	inout reg [31:0]  sd_data, // 32 bit bidirectional data bus
	output reg [10:0] sd_addr, // 11 bit multiplexed address bus
	output reg [3:0]  sd_dqm, // two byte masks
	output reg [1:0]  sd_ba, // two banks
	output		  sd_cs, // a single chip select
	output		  sd_we, // write enable
	output		  sd_ras, // row address select
	output		  sd_cas, // columns address select

	// cpu/chipset interface
	input		  clk, // sdram is accessed at 32MHz
	input		  reset_n, // init signal after FPGA config to initialize RAM

	output		  ready, // ram is ready and has been initialized
	input		  sync,
	input		  refresh,
	input [15:0]	  din, // data input from chipset/cpu
	output reg [15:0] dout,
	input [21:0]	  addr, // 22 bit word address
	input [1:0]	  ds, // upper/lower data strobe
	input		  cs, // cpu/chipset requests read/wrie
	input		  we          // cpu/chipset requests write
);

// The NanoMig runs this SDRAM at 72MHz asynchronously to the
// 28Mhz main clock. This means there are ~10 cycles per 7Mhz
// Amiga clock cycle
   
assign sd_clk = ~clk;
assign sd_cke = 1'b1;  
   
localparam RASCAS_DELAY   = 3'd2;   // tRCD=15ns -> 2 cycle@85MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 1'b0, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

// The state machine runs at 32Mhz synchronous to the sync signal.
localparam STATE_IDLE      = 3'd0;   // first state in cycle
localparam STATE_CMD_CONT  = STATE_IDLE + RASCAS_DELAY; // command can be continued (== state 2)
localparam STATE_READ      = STATE_CMD_CONT + CAS_LATENCY + 3'd1; // (== state 5)
localparam STATE_LAST      = 3'd6;  // last state in cycle

// Cycle pattern:
// 0 - STATE_IDLE - wait for 7MHz clock, perform RAS if CS is asserted
// 1 -              (read)                   (write) 
// 2 - perform CAS                           Drive bus
// 3 - 
// 4 -            - (chip launches data)
// 5 - STATE_READ - latch data
// 6 - STATE LAST - return to IDLE state

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

reg [2:0] state;
reg [4:0] init_state;

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
assign ready = !(|init_state);
   
// ---------------------------------------------------------------------
// ------------------ generate ram control signals ---------------------
// ---------------------------------------------------------------------

// all possible commands
localparam CMD_NOP             = 3'b111;
localparam CMD_ACTIVE          = 3'b011;
localparam CMD_READ            = 3'b101;
localparam CMD_WRITE           = 3'b100;
localparam CMD_BURST_TERMINATE = 3'b110;
localparam CMD_PRECHARGE       = 3'b010;
localparam CMD_AUTO_REFRESH    = 3'b001;
localparam CMD_LOAD_MODE       = 3'b000;

reg [2:0] sd_cmd;   // current command sent to sd ram
// drive control signals according to current command
assign sd_cs  = 1'b0;
assign sd_ras = sd_cmd[2];
assign sd_cas = sd_cmd[1];
assign sd_we  = sd_cmd[0];

// drive data to SDRAM on write
assign sd_data = we ? { din, din } : 32'bzzzz_zzzz_zzzz_zzzz_zzzz_zzzz_zzzz_zzzz;

localparam SYNCD = 2;

always @(posedge clk) begin
   reg [SYNCD:0] syncD;   
   sd_cmd <= CMD_NOP;  // default: idle

   // init state machines runs once reset ends
   if(!reset_n) begin
      init_state <= 5'h1f;
      state <= STATE_IDLE;      
   end else begin
      if(init_state != 0)
        state <= state + 3'd1;
      
      if((state == STATE_LAST) && (init_state != 0))
        init_state <= init_state - 5'd1;
   end
   
   if(init_state != 0) begin
      syncD <= 0;     
      
      // initialization takes place at the end of the reset
      if(state == STATE_IDLE) begin
	 
        if(init_state == 13) begin
            sd_cmd <= CMD_PRECHARGE;
            sd_addr[10] <= 1'b1;      // precharge all banks
        end
	 
        if(init_state == 2) begin
            sd_cmd <= CMD_LOAD_MODE;
            sd_addr <= MODE;
        end
	 
      end
   end else begin // if (init_state != 0)
      // add a delay tp the chipselect which in fact is just the beginning
      // of the 7MHz bus cycle
      syncD <= { syncD[SYNCD-1:0], sync };      
      
      // normal operation, start on ... 
      if(state == STATE_IDLE) begin
         // start a ram cycle at the rising edge of sync. In case of NanoMig
	 // this is actually the rising edge of the 7Mhz clock
         if (!syncD[SYNCD] && syncD[SYNCD-1]) begin
            state <= 3'd1;		 
	       
            if(cs) begin
	       if(!refresh) begin
		  // RAS phase
		  sd_cmd <= CMD_ACTIVE;
		  sd_addr <= addr[19:9];
		  sd_ba <= addr[21:20];

		  if(!we) sd_dqm <=  4'b0000;
		  else    sd_dqm <= addr[0]?{2'b11,ds}:{ds,2'b11};
	       end else		  
		 sd_cmd <= CMD_AUTO_REFRESH;	       
            end else
	      sd_cmd <= CMD_NOP;
         end
      end else begin
         // always advance state unless we are in idle state
         state <= state + 3'd1;
	 sd_cmd <= CMD_NOP;
	 
         // -------------------  cpu/chipset read/write ----------------------

         // CAS phase 
         if(state == STATE_CMD_CONT && !refresh) begin
	    if(cs) begin
	       sd_cmd <= we?CMD_WRITE:CMD_READ;
               sd_addr <= { 3'b100, addr[8:1] };
	    end else
              sd_cmd <= CMD_AUTO_REFRESH;
         end
	 
	 if(state == STATE_READ && !we)
	    dout <= addr[0]?sd_data[15:0]:sd_data[31:16];
	 
	 if(state == STATE_LAST) 
	   state <= STATE_IDLE;	    
      end
   end
end
   
endmodule
