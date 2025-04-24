`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
// No native support for 3.3v hdmi differential so we fake it

module framebuffer #(
    parameter int p_pixel_width       = 640,
    parameter int p_pixel_height      = 480, //+1 adjusted due to timings

    parameter int p_count_width = 16
    
    ) (
    input  logic i_clk_pixel,
    input  logic i_rst,
    input  logic i_frame,
    input  logic i_line,
    input  logic signed [p_count_width-1:0] i_x_pos,
    input  logic signed [p_count_width-1:0] i_y_pos,
    output logic debug_sig,
    output logic [7:0] o_data [3] // RGB data
);

    localparam signed c_x_start = 640/2-160/2;
    localparam signed c_x_end = p_pixel_width - 1;
    localparam signed c_y_start = 480/2-120/2;
    localparam signed c_y_end = p_pixel_height - 1;

    localparam int c_fb_width = 160;
    localparam int c_fb_depth = 120;
    localparam int c_fb_pixels = c_fb_depth * c_fb_width;
    localparam int c_fb_dataw = 1;
    localparam int c_fb_addrw = $clog2(c_fb_pixels);
    localparam int c_mem_latency = 1;

    logic [c_fb_dataw-1:0] s_fb_rd_data;
    logic [c_fb_addrw-1:0] s_fb_rd_addr;
    // framebuffer memory
    david_rom_sync inst_rom (
        .clk(i_clk_pixel),
        .addr(s_fb_rd_addr),
        .data(s_fb_rd_data)
    );
    // rom_sync #(
    //     .WIDTH(c_fb_dataw),
    //     .DEPTH(c_fb_pixels),
    //     .INIT_F(c_fb_image)
    // ) inst_rom (
    //     .clk(i_clk_pixel),
    //     .addr(s_fb_rd_addr),
    //     .data(s_fb_rd_data)
    // );
    // bram_sdp #(
    //     .WIDTH(c_fb_dataw),
    //     .DEPTH(c_fb_pixels),
    //     .INIT_F(c_fb_image)
    // ) bram_inst (
    //     .clk_write(i_clk_pixel),
    //     .clk_read(i_clk_pixel),
    //     .we(1'b0),
    //     .addr_write('0),
    //     .data_in('0),
    //     .addr_read(s_fb_rd_addr),
    //     .data_out(s_fb_rd_data)
    // );

    logic s_read_valid;
    logic s_draw_valid;
    logic unsigned [9:0] s_shift_cnt;
    logic unsigned [7:0] s_line_cnt;

    assign debug_sig = |s_fb_rd_data;
    assign o_data [0] = (s_draw_valid) ? (|s_fb_rd_data)? '1:'h0 : '0; 
    assign o_data [1] = (s_draw_valid) ? (|s_fb_rd_data)? '1:'h0 : s_line_cnt; 
    assign o_data [2] = (s_draw_valid) ? (|s_fb_rd_data)? '1:'h0 : 8'hf0; 
    always_ff @(posedge i_clk_pixel) begin
        if (i_rst) begin
            s_read_valid <= '0;
            s_draw_valid <= '0;
            s_fb_rd_addr <= '0;
            s_shift_cnt <= '0;
            s_line_cnt <= '0;
        end else begin
            s_read_valid <= (i_y_pos >= c_y_start + s_shift_cnt) 
                          & (i_y_pos < c_y_start + c_fb_depth+ s_shift_cnt)
                          & (i_x_pos >= c_x_start - c_mem_latency+ s_shift_cnt)
                          & (i_x_pos < c_x_start + c_fb_width - c_mem_latency+ s_shift_cnt);
            // s_read_valid <= (i_y_pos >= 0) 
            //               & (i_y_pos < c_fb_depth)
            //               & (i_x_pos >= 0 - c_mem_latency)
            //               & (i_x_pos < c_fb_width - c_mem_latency);
            s_draw_valid <= s_read_valid;
            if(i_line) s_line_cnt <= s_line_cnt + 1'b1;
            if (i_frame) begin
                // s_shift_cnt <= s_shift_cnt + 1'b1;
                s_fb_rd_addr <= '0;
            s_line_cnt <= '0;
            end else if(s_read_valid) begin
                s_fb_rd_addr <= s_fb_rd_addr + 1'b1;
            end
        end
    end
endmodule


