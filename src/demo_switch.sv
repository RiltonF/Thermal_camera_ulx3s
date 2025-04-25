`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module demo_switch #(
    parameter int p_states = 4
) (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_next,
    input  logic i_prev,
    output logic [p_states-1:0] o_state
);
    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            o_state <= {{(p_states-1){1'b0}},1'b1};
        end else begin
            if (i_next) o_state <= {o_state[p_states-2:0], o_state[p_states-1]};
            if (i_prev) o_state <= {o_state[0], o_state[p_states-1:1]};
        end
    end
endmodule


