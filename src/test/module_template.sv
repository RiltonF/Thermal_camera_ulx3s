`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module module_name #(
    parameter int p_foo = 10
) (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_blank,
    input  logic [7:0] i_data,
    output logic o_blank,
    output logic [7:0] o_data
);
    localparam int c_bar = 64;


    always_comb begin
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
        end else begin
        end
    end
endmodule


