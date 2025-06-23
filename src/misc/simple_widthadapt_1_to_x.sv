`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module simple_widthadapt_1_to_x #(
    parameter int p_iwidth = 16,
    parameter int p_x = 8, //Only powers of two
    localparam int p_owidth = p_iwidth * p_x,
    localparam int p_xw = $clog2(p_x)
) (
    input  logic i_clk,
    input  logic i_rst,

    input  logic                i_valid,
    input  logic [p_iwidth-1:0] i_data,
    output logic                o_ready,

    output logic                o_valid,
    output logic [p_owidth-1:0] o_data,
    output logic [p_iwidth-1:0] o_data_array [p_x],
    input  logic                i_ready
);
    logic [p_xw:0] s_fill_counter;
    logic          s_full;

    always_comb begin
        s_full = s_fill_counter >= p_x; //when full

        o_ready = ~s_full | (s_full & i_ready);
        o_valid = s_full;

        for (int i = 0; i < p_x; i++) begin
            o_data[i*p_iwidth +: p_iwidth] = o_data_array[i];
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_fill_counter <= '0;
        end else begin
            if (s_full) begin
                if (i_ready & i_valid) begin
                    //popped old data and directly loaded new one
                    o_data_array[0] <= i_data;
                    s_fill_counter <= 'd1;
                end
                else if (i_ready) begin
                    //popped old data but no new data available
                    s_fill_counter <= '0;
                end
            end else begin
                //load the new data
                if (i_valid) begin 
                    o_data_array[s_fill_counter] <= i_data;
                    s_fill_counter <= s_fill_counter + 1'b1; //increment counter
                end
            end
        end
    end
endmodule


