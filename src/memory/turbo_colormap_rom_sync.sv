// Project F Library - Synchronous ROM
// (C)2021 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module turbo_colormap_rom_sync #(
    parameter WIDTH=24,
    parameter DEPTH=256,
    `ifndef SIMULATION
    parameter INIT_F="turbo_colormap.hex",
    `else
    parameter INIT_F="../memory/turbo_colormap.hex",
    `endif

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
