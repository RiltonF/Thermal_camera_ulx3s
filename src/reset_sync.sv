`default_nettype none
`timescale 1ns / 1ps

module reset_sync #(
    // TODO: add option for sync assert as well
) (
    input  logic i_clk,
    input  logic i_async_rst,
    output logic o_rst
);
    logic [1:0] s_sync_pipe;

    assign o_rst = s_sync_pipe[1];

    always_ff @(posedge i_clk or posedge i_async_rst) begin
        if (i_async_rst) begin
            s_sync_pipe <= '1; //Async assert
        end else begin
            s_sync_pipe <= {s_sync_pipe[0], 1'b0}; //Sync deassert
        end
    end
endmodule


