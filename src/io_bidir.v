`timescale 1ns / 1ps
module io_bidir (
	inout B,
	input I,
	input T,
	output O
);

TRELLIS_IO #(.DIR("BIDIR")) inst_io_bidir (
	.B,
	.I,
	.T,
	.O
);
endmodule
