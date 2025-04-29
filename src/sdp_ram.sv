`default_nettype none
`timescale 1ns / 1ps

module sdp_ram #(
    parameter int WIDTH=640,
    parameter int DEPTH=480,
    localparam int ADDRW=$clog2(DEPTH)
    ) (
    input wire logic i_clk,
    input wire logic i_wr_valid,
    input wire logic [ADDRW-1:0] i_wr_addr,
    input wire logic [WIDTH-1:0] i_wr_data,
    input wire logic i_rd_req,
    input wire logic [ADDRW-1:0] i_rd_addr,
    output     logic [WIDTH-1:0] o_rd_data
    );

    logic [WIDTH-1:0] memory [DEPTH];

    always_ff @(posedge i_clk) begin
        if (i_wr_valid) memory[i_wr_addr] <= i_wr_data;
        if (i_rd_req) o_rd_data <= memory[i_rd_addr];
    end
endmodule
