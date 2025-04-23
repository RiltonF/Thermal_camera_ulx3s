`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
// No native support for 3.3v hdmi differential so we fake it

module vga_gen #(
    parameter int p_pixel_width       = 640,
    parameter int p_pixel_height      = 480, //+1 adjusted due to timings

    parameter int p_hsync_front_porch =  16,
    parameter int p_hsync_pulse       =  96,
    parameter int p_hsync_back_porch  =  48,

    parameter int p_vsync_front_porch =  10,
    parameter int p_vsync_pulse       =  2,
    parameter int p_vsync_back_porch  =  33,

    parameter bit p_hsync_polarity = 1, //0=neg, 1=pos
    parameter bit p_vsync_polarity = 1,  //0=neg, 1=pos
    parameter int p_count_width = 16
    
    ) (
    input  logic i_clk_pixel,
    input  logic i_rst,
    output logic o_hsync,
    output logic o_vsync,
    output logic o_data_en,
    output logic o_frame,
    output logic o_line,
    output logic [7:0] o_data_test [3], // RGB data
    output logic signed [p_count_width-1:0] o_x_pos,
    output logic signed [p_count_width-1:0] o_y_pos
);
    // We're first generating the blanking part, and then the visible part
    localparam signed c_x_origin = 0 - p_hsync_front_porch - p_hsync_pulse - p_hsync_back_porch;
    localparam signed c_hsync_start = c_x_origin + p_hsync_front_porch;
    localparam signed c_hsync_end = c_hsync_start + p_hsync_pulse;

    localparam signed c_y_origin = 0 - p_vsync_front_porch - p_vsync_pulse - p_vsync_back_porch;
    localparam signed c_vsync_start = c_y_origin + p_vsync_front_porch;
    localparam signed c_vsync_end = c_vsync_start + p_vsync_pulse;

    localparam signed c_x_start = 0;
    localparam signed c_x_end = p_pixel_width - 1;
    localparam signed c_y_start = 0;
    localparam signed c_y_end = p_pixel_height - 1;

    typedef struct packed {
        logic signed [p_count_width-1:0] x_counter;
        logic signed [p_count_width-1:0] y_counter;
        logic hsync;
        logic vsync;
        logic data_en;
        logic frame;
        logic line;
    } t_video_gen;

    t_video_gen s_r, s_r_next;

    localparam t_video_gen c_rst_val = '{
        hsync: p_hsync_polarity,
        vsync: p_vsync_polarity,
        default: '0
    };

    always_comb begin
        //init
        s_r_next = s_r;

        if (s_r.x_counter < c_x_end) begin
            s_r_next.x_counter++;
        end else begin
            s_r_next.x_counter = c_x_origin;
            s_r_next.y_counter = (s_r.y_counter < c_y_end) ? s_r.y_counter + 1'b1 : c_y_origin;
        end

        s_r_next.hsync = p_hsync_polarity ^ ((s_r.x_counter >= c_hsync_start) & (s_r.x_counter < c_hsync_end));
        s_r_next.vsync = p_vsync_polarity ^ ((s_r.y_counter >= c_vsync_start) & (s_r.y_counter < c_vsync_end));
        s_r_next.data_en = (s_r.x_counter >= c_x_start) & (s_r.y_counter >= c_y_start);

        s_r_next.frame = (s_r.x_counter == c_x_start) & (s_r.y_counter == c_y_start);
        s_r_next.line = s_r.x_counter == c_x_start;

        //output assignments
        o_hsync = s_r.hsync;
        o_vsync = s_r.vsync;
        o_data_en = s_r.data_en;
        o_frame = s_r.frame;
        o_line = s_r.line;
        o_x_pos = s_r.x_counter;
        o_y_pos = s_r.y_counter;
        // Red, Green, Blue
        o_data_test[2] = {s_r.x_counter[5:0] & {6{s_r.y_counter[4:3]==~s_r.x_counter[4:3]}}, 2'b00};
        o_data_test[1] = s_r.x_counter[7:0] & {8{s_r.y_counter[6]}};
        o_data_test[0] = s_r.y_counter[7:0];
    end

    always_ff @(posedge i_clk_pixel) begin
        if (i_rst) begin
            s_r <= c_rst_val;
            // s_r <= '0;
        end else begin
            s_r <= s_r_next;
        end
    end
endmodule


