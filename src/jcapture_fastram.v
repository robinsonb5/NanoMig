`default_nettype wire
module jcapture_fastram (
	input clk,
	input reset_n,
	input [23:0] addr,
	input wr,
	input ram_req,
	input ram_ack,
	input clk7_en,
	input clk_28m,
	output [255:0] q,
	output update
);
`default_nettype none
wire [255:0] bundle;

assign bundle[23:0] = addr;
assign bundle[24] = wr;
assign bundle[25] = ram_req;
assign bundle[26] = ram_ack;
assign bundle[27] = clk7_en;
assign bundle[28] = clk_28m;

jcapture cap (
	.clk(clk),
	.reset_n(reset_n),
	.d(bundle),
	.q(q),
	.update(update)
);

endmodule
`default_nettype wire
