// Project F Library - Synchronous ROM
// (C)2021 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module mlx90640_subpages_rom_sync #(
    parameter WIDTH=1,
    parameter DEPTH=32*24+64,
    `ifndef SIMULATION
    parameter INIT_F_pg0="mlx_subpage0_chess_pattern.mem",
    parameter INIT_F_pg1="mlx_subpage1_chess_pattern.mem",
    parameter INIT_F_offset="mlx90640_pixel_offsets.hex",
    `else
    parameter INIT_F_pg0="../memory/mlx_subpage0_chess_pattern.mem",
    parameter INIT_F_pg1="../memory/mlx_subpage1_chess_pattern.mem",
    parameter INIT_F_offset="../memory/mlx90640_pixel_offsets.hex",
    `endif
    localparam ADDRW=$clog2(DEPTH)
    ) (
    input wire logic clk,
    input wire logic [ADDRW-1:0] addr,
    output     logic [WIDTH-1:0] data_pg0,
    output     logic [WIDTH-1:0] data_pg1,
    output     logic [15:0] data_offsets
    );

    rom_sync #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .INIT_F(INIT_F_pg0)
    ) inst_pg0_rom (
        .clk,
        .addr,
        .data(data_pg0)
    );

    rom_sync #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .INIT_F(INIT_F_pg1)
    ) inst_pg1_rom (
        .clk,
        .addr,
        .data(data_pg1)
    );

    rom_sync #(
        .WIDTH(16),
        .DEPTH(DEPTH),
        .INIT_F(INIT_F_offset)
    ) inst_offset_rom (
        .clk,
        .addr,
        .data(data_offsets)
    );
endmodule
