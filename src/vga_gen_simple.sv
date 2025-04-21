`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
// No native support for 3.3v hdmi differential so we fake it

module vga_gen_simple (
    input  logic i_clk_pixel,
    input  logic i_rst,
    output logic o_hsync,
    output logic o_vsync,
    output logic o_blank,
    output logic [7:0] o_data_test [3], // RGB data
    output logic [9:0] o_x_pos, // update with $clog2?
    output logic [9:0] o_y_pos // update with $clog2?
);
    localparam int c_pixel_width       = 640;
    localparam int c_pixel_height      = 480; //+1 adjusted due to timings

    localparam int c_hsync_front_porch =  16;
    localparam int c_hsync_pulse       =  96;
    localparam int c_hsync_back_porch  =  48;

    localparam int c_hsync_start = c_pixel_width + c_hsync_front_porch-1;
    localparam int c_hsync_end = c_hsync_start + c_hsync_pulse;
    localparam int c_full_width = c_pixel_width + c_hsync_front_porch
                                + c_hsync_pulse + c_hsync_back_porch-1;

    localparam int c_vsync_front_porch =  10;
    localparam int c_vsync_pulse       =  2;
    localparam int c_vsync_back_porch  =  33;

    localparam int c_vsync_start = c_pixel_height + c_vsync_front_porch-1;
    localparam int c_vsync_end = c_vsync_start + c_vsync_pulse;
    localparam int c_full_height = c_pixel_height + c_vsync_front_porch
                                 + c_vsync_pulse + c_vsync_back_porch-1;

    logic [$clog2(c_full_width)-1:0] x_counter, x_counter_next;
    logic [$clog2(c_full_height)-1:0] y_counter, y_counter_next;

    assign o_x_pos = x_counter;
    assign o_y_pos = y_counter;

    always_comb begin
        x_counter_next = x_counter;
        y_counter_next = y_counter;

        if (x_counter < c_full_width) begin
            x_counter_next++;
        end else begin
            x_counter_next = '0;
            y_counter_next = (y_counter < c_full_height) ? y_counter + 1'b1 : '0;
        end

        o_hsync = ~((x_counter >= c_hsync_start) & (x_counter < c_hsync_end));
        o_vsync = ~((y_counter >= c_vsync_start) & (y_counter < c_vsync_end));
        o_blank = ~((x_counter < c_pixel_width) & (y_counter < c_pixel_height));
        // Red, Green, Blue
        o_data_test[2] = '0;
        o_data_test[1] = '0;
        o_data_test[0] = '0;
        // o_data_test[0] = y_counter[7:0];
        // o_data_test[1] = y_counter[7:0];
        // o_data_test[2] = y_counter[7:0];
        // o_data_test[2] = y_counter[2+:8];
        // o_data_test[1] = x_counter[2+:8];
        // o_data_test[0] = '1;
        o_data_test[2] = {x_counter[5:0] & {6{y_counter[4:3]==~x_counter[4:3]}}, 2'b00};
        o_data_test[1] = x_counter[7:0] & {8{y_counter[6]}};
        o_data_test[0] = y_counter[7:0];
    end

    always_ff @(posedge i_clk_pixel) begin
        if (i_rst) begin
            x_counter <= '0;
            y_counter <= '0;
        end else begin
            x_counter <= x_counter_next;
            y_counter <= y_counter_next;
        end
    end
endmodule


