#
# IceSugarPro demo JTAG script
#

init
scan_chain

# The total number of bits here must match the width defined in jcapture_pkg.vhd, hence the pad field at the end
set capture_fields {
	{ addr 24 }
	{ wr 1 }
	{ ram_req 1 }
	{ ram_ack 1 }
	{ clk7_en 1 }
	{ clk_28m 1 }
	{ pad 35 }
}

puts "Setting TAP, capture fields and length"

set loc [file dirname [file normalize [info script]]]
puts $loc

source ${loc}/jcapture.tcl
set capture_length [::jcapture::setup target.tap $capture_fields]


puts "Setting capture parameters..."

::jcapture::settrigger mask ram_req 0x1
::jcapture::settrigger edge ram_req 0x1
::jcapture::settrigger value ram_req 0x1

::jcapture::settrigger mask ram_ack 0x0

::jcapture::settrigger mask wr 0x0

::jcapture::settrigger mask addr 0xf00000
::jcapture::settrigger edge addr 0x000000
::jcapture::settrigger value addr 0x200000

::jcapture::setleadin 2

# Send capture parameters and start capturing...
::jcapture::capture

puts "Waiting for the FIFO"
::jcapture::wait_fifofull

puts "Collecting the FIFO contents"
::jcapture::dump_fifo

puts "Done."
exit


