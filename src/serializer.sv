`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
// No native support for 3.3v hdmi differential so we fake it

module serializer #(
    parameter int p_data_width = 10,
    parameter bit p_ddr_mode = 1
)(
    input  logic i_clk_data,
    input  logic i_clk_shift,
    input  logic i_rst,
    input  logic [p_data_width-1:0] i_data,
    output logic [1:0] o_data, //for Single Data Rate, you just use [0]
    output logic [1:0] o_clk //for Single Data Rate, you just use [0]
);
    logic [p_data_width-1:0] s_clk_out, s_data_shift;
    logic s_shift_clock_in_sync;
    logic s_skip_clk_shift;
    logic s_data_clock_old;

    localparam logic [p_data_width-1:0] c_init_count =
        {{(p_data_width/2){1'b0}}, {(p_data_width/2){1'b1}}} << 1+ p_ddr_mode;

    assign o_data = s_data_shift [1:0];
    assign o_clk = s_clk_out [1:0];

    // assign s_shift_clock_in_sync = (s_clk_out == c_init_count);
    always_ff @(posedge i_clk_data) begin
        if (i_rst) begin
            s_shift_clock_in_sync <= '0;
        end else begin
            //At the rising ede of i_clk_data, the shift clock should always be
            //equal to the init value, otherwise it's out of sync.
            s_shift_clock_in_sync <= (s_clk_out == c_init_count);
        end
    end

    always_ff @(posedge i_clk_shift) begin
        if (i_rst) begin
            s_data_clock_old <= '0;
            s_clk_out <= c_init_count;
            s_data_shift <= '0;
            s_skip_clk_shift <= '0;
        end else begin
            s_data_clock_old <= i_clk_data; //save old clock data

            //falling edge detection
            s_skip_clk_shift <= i_clk_data == 1'b0
                        & s_data_clock_old == 1'b1
                        & ~(s_shift_clock_in_sync);

            if (~s_skip_clk_shift) begin
                if (p_ddr_mode) begin
                    //shift to the right by two, ring buffer style
                    s_clk_out <= {s_clk_out[1:0], s_clk_out[p_data_width-1:2]};
                end else begin
                    //shift to the right by one, ring buffer style
                    s_clk_out <= {s_clk_out[0], s_clk_out[p_data_width-1:1]};
                end
            end

            if (s_clk_out == c_init_count) begin
                s_data_shift <= i_data;
            end else begin
                if (p_ddr_mode) begin
                    //shift to the right by two, ring buffer style
                    s_data_shift <= {s_data_shift[1:0], s_data_shift[p_data_width-1:2]};
                end else begin
                    //shift to the right by one, ring buffer style
                    s_data_shift <= {s_data_shift[0], s_data_shift[p_data_width-1:1]};
                end
            end
        end
    end
endmodule


