// Project F Library - Synchronous ROM
// (C)2021 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module david_rom_sync #(
    parameter WIDTH=1,
    parameter DEPTH=160*120,
    parameter INIT_F="test_box_mono_160x120.mem",
    localparam ADDRW=$clog2(DEPTH)
    ) (
    input wire logic clk,
    input wire logic [ADDRW-1:0] addr,
    output     logic [WIDTH-1:0] data
    );

    rom_sync #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .INIT_F(INIT_F)
    ) rom_inst (
        .clk,
        .addr,
        .data
    );
endmodule
