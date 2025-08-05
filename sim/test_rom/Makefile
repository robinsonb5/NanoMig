#
# Makefile
#

all: test_rom.bin

test_rom.bin: test_rom.s
	/opt/m68k-elf/bin/vasmm68k_mot -Fbin test_rom.s -o test_rom.bin
