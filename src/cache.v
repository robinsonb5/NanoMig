`default_nettype none

module cache
#(
	parameter          sdramwidth_log2 = 2,   // In bytes, not bits
	parameter          burstlength_log2 = 2,  // 4 word bursts by default
	parameter          cachesize_log2 = 14    // 16kbit by default
) (
	// System
	input wire         clk85,
	input wire         clk28,
	input wire         reset_n,
	output wire        ready,

	// CPU interface
	input  wire        cpu_req,
	input  wire [23:1] cpu_addr,
	output reg [(2**(sdramwidth_log2+3))-1:0] cpu_q, // Word selection is the host's problem.
	input  wire        cpu_we,
	output reg         cpu_ack,
	
	// SDRAM interface
	input wire [31:0]  sd_d,
	output reg         sd_req,
	input wire         sd_fill,

	output wire        dbg_tag_stable,
	output wire        dbg_tag_valid
);


// Sync with the CPU
reg toggle28=1'b0;
always @(posedge clk28)
	toggle28 <= ~toggle28;

reg toggle28_d;
always @(posedge clk85)
	toggle28_d <= toggle28;

wire edge28 = toggle28 ^ toggle28_d; // Momentary pulse in 85MHz domain, immediately prior to clk28 rising edge

reg [2:0] phase;	// Address is stable when phase[1] = 1, tag is valid when phase[0] = 1
always @(posedge clk85)
	phase <= {edge28,phase[2],cpu_req&phase[1]};

wire addr_stable = phase[1];

reg tag_stable;
always @(posedge clk85) begin
	if(cpu_req & addr_stable)
		tag_stable <= 1'b1;
	if(cpu_ack & phase[1])
		tag_stable <= 1'b0;
end

always @(posedge clk85) begin
	if (ready & cpu_req & tag_stable & (cpu_we | ~tag_hit) & ~cpu_ack)
		sd_req <= 1'b1;
	if (sd_fill)
		sd_req <= 1'b0;
end


// If the RAM blocks are 16kbit then 32 bit wide RAM
// over four word bursts will give us 128 cachelines per RAM block.

localparam sdramwidth_bits = (2**sdramwidth_log2)*8;
localparam cachelines_log2 = cachesize_log2 - (burstlength_log2 + sdramwidth_log2 + 3);

// CPU address must be divded into a tax, an index and word

// Active CPU address range is 23:1, CPU bus is 16 bits wide,

// Cacheline word will thus be cpu_addr[burstlength_log2 + sdramwidth_log2 - 1 : sdramwidth_log2]
// so with 32-bit wide SDRAM and 4 word bursts, cpu_addr[3:2] 

// Tag index will be the next cachelines_log2 bits (so cpu_addr[10:4])

// and the tag itself will be the remaining bits. (so cpu_addr[23:11] - 13 bits
// leaving two bits of headroom for expansion to 32 or 64 meg address space.)

localparam cache_word_low = sdramwidth_log2;
localparam cache_word_high = burstlength_log2 + sdramwidth_log2 - 1;

// Cacheline index is a slice of the CPU address
localparam cache_idx_low = cache_word_high + 1;
localparam cache_idx_high = cache_idx_low + cachelines_log2-1;

localparam tag_low = cache_idx_high + 1;
localparam tag_high = 23;


reg tag_init;
reg [cachelines_log2-1:0] tag_init_a;

wire [cachelines_log2-1:0] tag_a = tag_init ? tag_init_a : cpu_addr[cache_idx_high:cache_idx_low];
reg [15:0] tag_d;
reg tag_we;

// Tag storage

reg [15:0] tagram [2**cachelines_log2];
reg [15:0] tag;

always @(posedge clk85) begin
	if(tag_we)
		tagram[tag_a]<=tag_d;
	tag <= tagram[tag_a];
end

wire tag_valid = tag[15];
wire tag_hit = tag_valid && (cpu_addr[tag_high:tag_low] == tag[tag_high-tag_low:0]);

reg cache_valid;
// Allow the CPU to continue once
// either the SDRAM controller responds to a write,
// or a read from SDRAM has completed.
reg cpu_ack_i;
always @(*)
	cpu_ack_i <= tag_stable & ((sd_fill & sd_fill_d & cpu_we) // Write: ack for only three of the four fill cycles - FIXME adjust for 8 word bursts
	               || (tag_valid && tag_hit && ~cpu_we));// && !sd_fill); // Read

always @(posedge clk28)
	cpu_ack <= cpu_ack_i & ~cpu_ack;

// Register whether or not this is a write cycle
reg writecycle;
always @(posedge clk85) begin
	if(!sd_fill)
		writecycle=cpu_we;
end


// Initialise

reg sd_fill_d;
always @(posedge clk85) begin
	
	tag_we <= 1'b0;
	
	// In normal operation we update the tag when the first read from SDRAM comes in, or on write.

	tag_d[15] <= ~cpu_we; // Invalidate the cacheline on write
	tag_d[tag_high-tag_low:0] <= cpu_addr[tag_high:tag_low];
	sd_fill_d <= sd_fill;
	tag_we <= sd_fill && !sd_fill_d;

	// During init, mark all tags invalid
	
	if(tag_init) begin
		tag_d <= 16'h0000;
		tag_we <= 1'b1;
		if(&tag_init_a)
			tag_init<=1'b0;
		tag_init_a <= tag_init_a + 1;
	end

	if(!reset_n) begin
		tag_init <= 1'b1;
		tag_init_a <= 0;
	end
end

assign ready = ~tag_init;

// Data RAM - simple dual port RAM - one read, one write port.

localparam datawords_log2 = cachelines_log2 + burstlength_log2;

reg [sdramwidth_bits-1:0] dataram [2**datawords_log2]; // Four word bursts, 128 cachelines


// Read port
wire [datawords_log2-1:0]   d_a;
wire [burstlength_log2-1:0] d_word;	// Specific word within the cacheline
wire [cachelines_log2-1:0]  d_line;	// Index of the cacheline
reg  [sdramwidth_bits-1:0] d_q;

assign d_line = cpu_addr[cache_idx_high:cache_idx_low];
assign d_word = cpu_addr[cache_word_high:cache_word_low];
assign d_a = {d_line,d_word};

always @(posedge clk85) begin
	cpu_q <= dataram[d_a];
end


// Write port
wire [cachelines_log2+burstlength_log2-1:0] d_w_a;
reg [burstlength_log2-1:0]  d_w_word;
//reg [cachelines_log2-1:0]  d_w_line;

always @(posedge clk85) begin
	if(sd_fill & ~writecycle)
		dataram[d_w_a] <= sd_d;
end

assign d_w_a = {d_line,d_w_word};

always @(posedge clk85) begin
	if(sd_fill)
		d_w_word <= d_w_word + 2'b1;
	else
		d_w_word <= cpu_addr[cache_word_high:cache_word_low];
end

assign dbg_tag_stable = tag_stable;
assign dbg_tag_valid = tag_valid;

endmodule
`default_nettype wire

