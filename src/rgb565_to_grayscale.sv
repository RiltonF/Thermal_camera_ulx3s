`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module rgb565_to_grayscale (
    input  logic i_clk,
    input  logic i_rst,
    input  logic [15:0] i_rgb,
    output logic [7:0] o_gray,
    output logic [15:0] o_gray_rgb
);
    wire [7:0] s_red   = {i_rgb[15:11], 3'h0};
    wire [7:0] s_green = {i_rgb[10:5], 2'h0};
    wire [7:0] s_blue  = {i_rgb[4:0], 3'h0};

    wire [3:0] s_gray_4bit = o_gray[7:4];
    assign o_gray_rgb = {4{s_gray_4bit}};
    // assign o_gray = (s_red + s_green + s_blue)/3;
    assign o_gray = (s_red*'d77 + s_green*'d150 + s_blue*'d29) >> 8;

    // always_ff @(posedge i_clk) begin
    //     if (i_rst) begin
    //         o_gray <= '0;
    //     end else begin
    //         // o_gray <= (s_red + s_green + s_blue)/3;
    //         o_gray <= (s_red*'d77 + s_green*'d150 + s_blue*'d29) >> 8;
    //     end
    // end
endmodule


