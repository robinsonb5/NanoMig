// A wrapper for the Gowin GW_JTAG primitive.

// It doesn't seem to be possible to instantiate this directly from VHDL
// for two reasons:

// * Setting the syn_black_box attribute to true from VHDL doesn't seem to work,

// * In order to have the *_pad_* signals implicitly connected to the internal JTAG signals,
// they must be left unconnected in the instantiation, which is not  legal in VHDL.
// Hence a thin wrapper in Verilog which leaved the pad signals unconnected.

module GW_JTAG (
	tck_pad_i,
	tms_pad_i,
	tdi_pad_i,
	tdo_pad_o,
	tck_o,                //DRCK_IN
	tdi_o,                //TDI_IN
	test_logic_reset_o,   //RESET_IN
	run_test_idle_er1_o,   
	run_test_idle_er2_o,   
	shift_dr_capture_dr_o,//SHIFT_IN|CAPTURE_IN
	pause_dr_o,     
	update_dr_o,          //UPDATE_IN
	enable_er1_o,         //SEL_IN
	enable_er2_o,         //SEL_IN
	tdo_er1_i,            //TDO_OUT
	tdo_er2_i             //TDO_OUT
)/* synthesis syn_black_box  */;

input wire tck_pad_i;
input wire tms_pad_i;
input wire tdi_pad_i;
output wire tdo_pad_o;
input wire tdo_er1_i;
input wire tdo_er2_i;
output wire tck_o;
output wire tdi_o;
output wire test_logic_reset_o;
output wire run_test_idle_er1_o;
output wire run_test_idle_er2_o;
output wire shift_dr_capture_dr_o;
output wire pause_dr_o;
output wire update_dr_o;
output wire enable_er1_o;
output wire enable_er2_o;

endmodule

// Wrap the GW_JTAG module leaving the physical pins unconnected - should then be usable from VHDL
module gwjtag_wrapper (
	tck_o,                //DRCK_IN
	tdi_o,                //TDI_IN
	test_logic_reset_o,   //RESET_IN
	run_test_idle_er1_o,   
	run_test_idle_er2_o,   
	shift_dr_capture_dr_o,//SHIFT_IN|CAPTURE_IN
	pause_dr_o,     
	update_dr_o,          //UPDATE_IN
	enable_er1_o,         //SEL_IN
	enable_er2_o,         //SEL_IN
	tdo_er1_i,            //TDO_OUT
	tdo_er2_i             //TDO_OUT
);

input wire tdo_er1_i;
input wire tdo_er2_i;
output wire tck_o;
output wire tdi_o;
output wire test_logic_reset_o;
output wire run_test_idle_er1_o;
output wire run_test_idle_er2_o;
output wire shift_dr_capture_dr_o;
output wire pause_dr_o;
output wire update_dr_o;
output wire enable_er1_o;
output wire enable_er2_o;

GW_JTAG jtagshim (
	.tck_o(tck_o),                //DRCK_IN
	.tdi_o(tdi_o),                //TDI_IN
	.test_logic_reset_o(test_logic_reset_o),   //RESET_IN
	.run_test_idle_er1_o(run_test_idle_er1_o),   
	.run_test_idle_er2_o(run_test_idle_er2_o),   
	.shift_dr_capture_dr_o(shift_dr_capture_dr_o),//SHIFT_IN|CAPTURE_IN
	.pause_dr_o(pause_dr_o),     
	.update_dr_o(update_dr_o),          //UPDATE_IN
	.enable_er1_o(enable_er1_o),         //SEL_IN
	.enable_er2_o(enable_er2_o),         //SEL_IN
	.tdo_er1_i(tdo_er1_i),            //TDO_OUT
	.tdo_er2_i(tdo_er2_i)             //TDO_OUT
);

endmodule
