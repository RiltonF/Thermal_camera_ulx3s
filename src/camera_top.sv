`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
import package_cam::*;

module camera_top #(
    parameter int p_scaler = 1,
    parameter int p_pixel_width  = 640,
    parameter int p_pixel_height = 480,

    parameter int p_count_width = 16,

    localparam int c_fb_width = 640/2**p_scaler,
    localparam int c_fb_height = 480/2**p_scaler,

    localparam int c_fb_pixels = c_fb_height * c_fb_width,
    localparam int c_fb_dataw = 16,
    localparam int c_fb_addrw = $clog2(c_fb_pixels),

    localparam int c_mem_latency = 1,
    localparam signed c_x_start = 100,
    localparam signed c_x_end = p_pixel_width - 1,
    localparam signed c_y_start = 100,
    localparam signed c_y_end = p_pixel_height - 1
    ) (
    input  logic i_clk,
    input  logic i_rst,
    input  t_cam_signals i_camera,
    input  logic i_frame,
    input  logic i_line,
    input  logic signed [p_count_width-1:0] i_x_pos,
    input  logic signed [p_count_width-1:0] i_y_pos,
    output logic debug_sig,
    output [7:0]led,
    output logic [7:0] o_data [3] // RGB data
);
    logic unsigned [7:0] s_line_cnt;

    logic                  s_fb_wr_valid;
    logic [c_fb_dataw-1:0] s_fb_wr_data;
    logic [c_fb_addrw-1:0] s_fb_wr_addr;
    logic                  s_fb_rd_valid;
    logic [c_fb_dataw-1:0] s_fb_rd_data;
    logic [c_fb_addrw-1:0] s_fb_rd_addr;
    logic [9:0] s_wr_row, s_wr_col;

    // assign s_fb_wr_addr = {s_wr_col,s_wr_row};
    // assign s_fb_wr_addr = s_wr_col<<7 + s_wr_col <<5 + s_wr_row;
    assign s_fb_wr_addr = s_wr_row*160 + s_wr_col;
    // assign s_fb_wr_addr = s_wr_row<<7 + s_wr_row<<5 + s_wr_col;

    assign led[7:1] = s_wr_col;
    assign led[0] = s_fb_wr_valid;
    dc_dp_ram #(
        .WIDTH(c_fb_dataw),
        .DEPTH(c_fb_pixels)
    ) inst_fb (
        .i_clk_rd(i_clk),
        .i_clk_wr(i_camera.clk_pixel),
        .i_wr_valid(s_fb_wr_valid),
        .i_wr_addr(s_fb_wr_addr),
        .i_wr_data(s_fb_wr_data),
        .i_rd_req(s_fb_rd_valid),
        .i_rd_addr(s_fb_rd_addr),
        .o_rd_data(s_fb_rd_data)
    );

    camera_read inst_camera_read (
      .i_clk       (i_camera.clk_pixel),
      .i_rst       (i_rst),
      .i_vsync     (i_camera.vsync),
      .i_href      (i_camera.href),
      .i_data      (i_camera.data),
      .o_valid     (s_fb_wr_valid),
      .o_data      (s_fb_wr_data),
      .o_frame_done(),
      .o_row       (s_wr_row),
      .o_col       (s_wr_col)
    );

    logic s_read_valid;
    logic s_draw_valid;

    assign s_fb_rd_valid = s_read_valid;
    assign debug_sig = |s_fb_rd_data;
    assign o_data [2] = (s_draw_valid)? { s_fb_rd_data [15:11], 3'b000}: '0;
    assign o_data [1] = (s_draw_valid)? { s_fb_rd_data [10:5], 2'b00} : s_line_cnt;
    assign o_data [0] = (s_draw_valid)? { s_fb_rd_data [4:0] , 3'b000}: i_x_pos;
    // assign o_data [2] = (s_draw_valid)? '1: '0;
    // assign o_data [1] = (s_draw_valid)? '1: s_line_cnt;
    // assign o_data [0] = (s_draw_valid)? '1: i_x_pos;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_read_valid <= '0;
            s_draw_valid <= '0;
            s_fb_rd_addr <= '0;
            s_line_cnt <= '0;
        end else begin
            s_read_valid <= (i_y_pos >= c_y_start)
                          & (i_y_pos < c_y_start + c_fb_height)
                          & (i_x_pos >= c_x_start - c_mem_latency)
                          & (i_x_pos < c_x_start + c_fb_width - c_mem_latency);
            s_draw_valid <= s_read_valid;
          if(i_line) begin
              s_line_cnt <= s_line_cnt + 1'b1;
          end
            if (i_frame) begin
                s_fb_rd_addr <= '0;
                s_line_cnt <= '0;
            end else if(s_read_valid) begin
                s_fb_rd_addr <= s_fb_rd_addr + 1'b1;
            end
        end
    end
endmodule


