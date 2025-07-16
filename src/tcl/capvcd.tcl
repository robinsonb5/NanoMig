#
# IceSugarPro demo JTAG script
#

# This will attempt to create a FIFO named capture.vcd, then repeatedly perform captures,
# writing the result in VCD format.

# Since opening the FIFO for writing blocks until something else has opened it for reading,
# the capture won't begin until, for example, you open the VCD file in GTKWave

# Better yet, subsequent captures will be delayed until the file is re-opened, so you
# can simply click the refresh button in GTKWave to perform a new capture.


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
source ${loc}/jcapture.tcl

set capture_length [::jcapture::setup target.tap $capture_fields]

::jcapture::settrigger mask ram_req 0x1
::jcapture::settrigger edge ram_req 0x1
::jcapture::settrigger value ram_req 0x1

::jcapture::settrigger mask ram_ack 0x0

::jcapture::settrigger mask wr 0x0

::jcapture::settrigger mask addr 0xf00000
::jcapture::settrigger edge addr 0x000000
::jcapture::settrigger value addr 0x200000

# Create a FIFO 
if [catch {exec mkfifo capture.vcd}] {
	puts "mkfifo failed - probably already exists?"
}

puts "Recording to capture.vcd - reading or re-reading from this FIFO will trigger a capture"

while {1} {
	set chan [::jcapture::create_vcd capture.vcd -31]
	puts "Capturing..."
	::jcapture::setleadin 3
	::jcapture::capture
	::jcapture::wait_fifofull
	::jcapture::fifo_to_vcd $chan 
	puts "Capture complete"
	after 100
}

exit


