// Project F Library - Synchronous ROM
// (C)2021 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module ov7670_rom_sync #(
    parameter WIDTH=16,
    parameter DEPTH=2**8,
    `ifndef SIMULATION
    parameter INIT_F="ov7670_config.mem",
    `else
    //need to give path from tb file, not rom_sync for simulation
    parameter INIT_F="../memory/ov7670_config.mem",
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
