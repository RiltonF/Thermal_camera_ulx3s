`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module simple_widthadapt_x_to_1 #(
    parameter int p_iwidth = 16,
    parameter int p_x = 8, //Only powers of two
    localparam int p_owidth = p_iwidth / p_x,
    localparam int p_xw = $clog2(p_x)
) (
    input  logic i_clk,
    input  logic i_rst,

    input  logic                i_valid,
    input  logic [p_iwidth-1:0] i_data,
    output logic                o_ready,

    output logic                o_valid,
    output logic [p_owidth-1:0] o_data,
    input  logic                i_ready
);
    logic [p_xw:0] s_level_counter;
    logic          s_empty;
    logic          s_almost_empty;
    logic [p_iwidth-1:0] s_buffer;

    always_comb begin
        s_empty = s_level_counter == 0;
        s_almost_empty = s_level_counter == 1;

        o_ready = s_empty | (s_almost_empty & i_ready);
        o_valid = ~s_empty;

        o_data = s_buffer[(s_level_counter-1)*p_owidth +: p_owidth];
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_level_counter <= '0;
        end else begin
            if (s_empty) begin
                if (i_valid) begin
                    s_buffer <= i_data;
                    s_level_counter <= p_x;
                end
            end
            else if (s_almost_empty) begin
                if (i_ready & i_valid) begin
                    s_buffer <= i_data;
                    s_level_counter <= p_x;
                end
                else if (i_ready) begin
                    s_level_counter <= 0;
                end
            end else begin
                //load the new data
                if (i_ready) begin 
                    s_level_counter <= s_level_counter - 1'b1; //decrement counter
                end
            end
        end
    end
endmodule


