`default_nettype none
/* verilator lint_off WIDTHEXPAND */
// No native support for 3.3v hdmi differential so we fake it

module fake_differential (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_data,
    output logic o_data_p,
    output logic o_data_n
);
    logic s_data_p,s_data_n;

    assign o_data_p = s_data_p;
    assign o_data_n = s_data_n;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_data_p <= '0;
            s_data_n <= '0;
        end else begin
            s_data_p <= i_data;
            s_data_n <= ~i_data; //invert
        end
    end
endmodule


