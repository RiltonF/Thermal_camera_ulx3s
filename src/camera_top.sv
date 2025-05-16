`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
import package_cam::*;

module camera_top #(
    parameter int p_fb_upscale = 2,
    parameter int p_scaler = 1,
    parameter int p_pixel_width  = 640,
    parameter int p_pixel_height = 480,

    parameter int p_count_width = 16,

    localparam int c_fb_width = 640/2**p_scaler,
    localparam int c_fb_height = 480/2**p_scaler,

    localparam int c_fb_pixels = c_fb_height * c_fb_width,
    localparam int c_fb_dataw = 16,
    localparam int c_fb_addrw = $clog2(c_fb_pixels),

    localparam int c_mem_latency = 2,
    localparam signed c_x_start = 0,
    localparam signed c_x_end = p_pixel_width - 1,
    localparam signed c_y_start = 0,
    localparam signed c_y_end = p_pixel_height - 1
    ) (
    input  logic i_clk,
    input  logic i_rst,
    input  t_cam_signals i_camera,
    input  logic i_frame,
    input  logic i_line,
    input  logic signed [p_count_width-1:0] i_x_pos,
    input  logic signed [p_count_width-1:0] i_y_pos,
    input logic i_toggle,
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
    assign s_fb_wr_addr = (s_wr_row<<7) + (s_wr_row<<5) + s_wr_col - 1;

    assign led[7:1] = s_wr_col;
    assign led[0] = s_fb_wr_valid;

    logic [7:0] s_gray_data;
    rgb565_to_grayscale inst_grayscale (
        .i_clk       (i_clk),
        .i_rst       (i_rst),
        .i_rgb       (s_fb_rd_data),
        // .o_gray_rgb  (s_wr_gray_data)
        .o_gray(s_gray_data)
    );


    dc_dp_ram #(
        .WIDTH(c_fb_dataw),
        .DEPTH(c_fb_pixels)
    ) inst_fb (
        .i_clk_rd(i_clk),
        .i_clk_wr(i_camera.clk_pixel),
        .i_wr_valid(s_fb_wr_valid),
        .i_wr_addr(s_fb_wr_addr),
        .i_wr_data((s_fb_wr_addr == 160) ? '1: s_fb_wr_data),
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
    logic [2:0] s_draw_valid;
    logic [p_fb_upscale-1:0] s_scalex_count;
    logic [p_fb_upscale-1:0] s_scaley_count;
    logic [c_fb_addrw-1:0] s_scaley_addr_hold;
    logic s_switch;
    wire [7:0] r_grey = { s_gray_data [7:3], 3'b000};
    wire [7:0] g_grey = { s_gray_data [7:2], 2'b000};
    wire [7:0] b_grey = { s_gray_data [7:3], 3'b000};
    wire [7:0] r_color = { s_fb_rd_data [15:11], 3'b000};
    wire [7:0] g_color = { s_fb_rd_data [10:5], 2'b000};
    wire [7:0] b_color = { s_fb_rd_data [4:0], 3'b000};


    assign s_fb_rd_valid = s_read_valid;
    always_comb begin
        if(s_switch) begin
            o_data [2] = (s_draw_valid[1])? r_grey: '0;
            o_data [1] = (s_draw_valid[1])? g_grey: s_line_cnt;
            o_data [0] = (s_draw_valid[1])? b_grey: i_x_pos;
        end else begin
            o_data [2] = (s_draw_valid[1])? r_color: '0;
            o_data [1] = (s_draw_valid[1])? g_color: s_line_cnt;
            o_data [0] = (s_draw_valid[1])? b_color: i_x_pos;
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_read_valid <= '0;
            s_draw_valid <= '0;
            s_fb_rd_addr <= '0;
            s_line_cnt <= '0;
            s_switch <= '0;
        end else begin
            if (i_toggle) s_switch <= ~s_switch;
            s_read_valid <= (i_y_pos >= c_y_start )
                          & (i_y_pos < c_y_start + (c_fb_height << p_fb_upscale))
                          & (i_x_pos >= c_x_start - c_mem_latency)
                          & (i_x_pos < c_x_start + (c_fb_width << p_fb_upscale) - c_mem_latency);
            s_draw_valid <= {s_draw_valid[1:0], s_read_valid}; //shift register for read valid
          if (i_frame) begin
              s_fb_rd_addr <= '0;
              s_line_cnt <= '0;
              s_scalex_count <= '0;
              s_scaley_count <= '0;
              s_scaley_addr_hold <= '0;
          end else if(i_line) begin
              s_line_cnt <= s_line_cnt + 1'b1;
              if(p_fb_upscale > 0) begin
                  if (s_fb_rd_addr > 0) begin
                      s_scaley_count <= s_scaley_count + 1;
                      if(s_scaley_count == 0) begin
                          s_scaley_addr_hold <= s_fb_rd_addr;
                      end else begin
                          s_fb_rd_addr <= s_scaley_addr_hold;
                      end
                  end
              end
          end else if(s_read_valid) begin
              if(p_fb_upscale == 0) begin
                  s_fb_rd_addr <= s_fb_rd_addr + 1'b1;
              end else begin
                  s_scalex_count <= s_scalex_count + 1;
                  if(&s_scalex_count) begin
                      s_fb_rd_addr <= s_fb_rd_addr + 1'b1;
                  end
              end
          end
        end
    end
endmodule


