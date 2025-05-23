`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
import package_cam::*;

module camera_top #(
    parameter int p_fb_upscale = 2,

    parameter int p_count_width = 16,

    localparam int c_fb_width = 160,
    localparam int c_fb_height = 120,

    localparam int c_fb_pixels = c_fb_height * c_fb_width,
    localparam int c_fb_dataw = 16,
    localparam int c_fb_addrw = $clog2(c_fb_pixels)
    ) (
    input  logic i_clk,
    input  logic i_rst,
    input  t_cam_signals i_camera,
    output logic o_de,
    output logic o_hsync,
    output logic o_vsync,
    input logic i_toggle,
    output [7:0]led,
    output logic [7:0] o_data [3] // RGB data
);
    logic signed [p_count_width-1:0] vga_x_pos;
    logic signed [p_count_width-1:0] vga_y_pos;

    logic [1:0] s_switch;
    logic                  s_fb_wr_valid;
    logic [c_fb_dataw-1:0] s_fb_wr_data;
    logic [c_fb_addrw-1:0] s_fb_wr_addr;
    logic                  s_fb_rd_valid;
    logic [c_fb_dataw-1:0] s_fb_rd_data;
    logic [c_fb_addrw-1:0] s_fb_rd_addr;
    logic [9:0] s_wr_y, s_wr_x;
    logic [9:0] s_rd_y, s_rd_x;

    assign s_rd_x = (vga_x_pos>>2); //scaling by 4x
    assign s_rd_y = (vga_y_pos>>2);
    assign s_fb_rd_addr = (s_rd_y<<7) + (s_rd_y<<5) + s_rd_x;

    assign s_fb_wr_addr = (s_wr_y<<7) + (s_wr_y<<5) + s_wr_x;

    localparam int c_shift = 5;
    logic [c_shift-1:0]s_shift_hsync;
    logic [c_shift-1:0]s_shift_vsync;
    logic [c_shift-1:0]s_shift_de;
    logic s_hsync;
    logic s_vsync;
    logic s_de;
    logic s_frame;
    logic s_data_valid;
    // logic [c_fb_addrw-1:0] s_edge_addr;

    assign s_fb_rd_valid = s_de & ~|vga_x_pos[1:0] & ($signed(vga_x_pos)>=0);
    always_ff @(posedge i_clk) begin
        s_shift_hsync <= {s_shift_hsync[c_shift-2:0],s_hsync};
        s_shift_vsync <= {s_shift_vsync[c_shift-2:0],s_vsync};
        s_shift_de <= {s_shift_de[c_shift-2:0],s_de};
        s_data_valid <= s_fb_rd_valid;
        // s_edge_addr <= s_fb_rd_addr;
    end

    logic [7:0] s_gray_data;
    //pure combinatorial
    rgb565_to_grayscale inst_grayscale (
        .i_clk       (i_clk),
        .i_rst       (i_rst),
        .i_rgb       (s_fb_rd_data),
        .o_gray(s_gray_data)
    );

    logic [10:0] s_edge_data;
    logic [10:0] s_edge_data_pre;
    logic s_edge_valid;
    logic [c_fb_addrw-1:0] s_edge_addr;
    logic [8-1:0] s_edge_rd_data;

    logic [7:0] s_gray_data_pre;
    rgb565_to_grayscale inst_grayscale_pre (
        .i_clk(i_camera.clk_pixel),
        .i_rst       (i_rst),
        .i_rgb       (s_fb_wr_data),
        // .i_rgb       (
        // {s_fb_wr_data[15:11]<<1,
        // 6'(s_fb_wr_data[10:5]<<1),
        // 5'(s_fb_wr_data[4:0]<<1)}),
        .o_gray(s_gray_data_pre)
    );
    sobel_filter #(
        .p_x_max(c_fb_width),
        .p_y_max(c_fb_height),
        .p_data_width(8)
    ) inst_sobel_filter (
        .i_clk(i_camera.clk_pixel),
        .i_rst(i_rst|(s_fb_wr_addr == 0 & ~s_fb_wr_valid)), //keep aligned with camera frame
        .i_valid(s_fb_wr_valid),
        .i_data(s_gray_data_pre >> s_switch),
        .o_valid(s_edge_valid),
        .o_data(s_edge_data_pre),
        .o_addr(s_edge_addr)
    );
    dc_dp_ram #(
        .WIDTH(8),
        .DEPTH(c_fb_pixels)
    ) inst_edge_mem (
        .i_clk_rd(i_clk),
        .i_clk_wr(i_camera.clk_pixel),
        .i_wr_valid(s_edge_valid),
        .i_wr_addr (s_edge_addr),
        .i_wr_data (s_edge_data_pre),
        .i_rd_req  (s_fb_rd_valid),
        .i_rd_addr (s_fb_rd_addr),
        .o_rd_data (s_edge_rd_data)
    );
    assign led = {s_edge_addr, s_edge_valid, s_fb_wr_valid}; 
    // sobel_filter #(
    //     .p_x_max(c_fb_width),
    //     .p_y_max(c_fb_height),
    //     .p_data_width(8)
    // ) inst_sobel_filter (
    //     .i_clk       (i_clk),
    //     .i_rst       (i_rst),
    //     // .i_rst       (i_rst|s_frame),
    //     .i_valid(s_data_valid),
    //     .i_data(s_gray_data),
    //     .o_valid(s_edge_valid),
    //     .o_data(s_edge_data),
    //     .o_addr(s_edge_addr)
    // );

    // mu_ram_1r1w #(
    //     .DW(8),
    //     .AW(c_fb_addrw)
    // ) inst_edge_mem(
    //     .clk(i_clk),
    //     //Read interface
    //     .re(s_fb_rd_valid),
    //     .raddr(s_fb_rd_addr),
    //     .rd(s_edge_rd_data),
    //     //Write interface
    //     .we(s_edge_valid),
    //     .waddr(s_edge_addr),
    //     // .wr(s_edge_addr)
    //     .wr(s_edge_data>>2)
    // );

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
      .o_row       (s_wr_y),
      .o_col       (s_wr_x)
    );

    logic s_read_valid;
    // wire [7:0] r_edge = { s_edge_data >> 2};
    // wire [7:0] g_edge = { s_edge_data >> 2};
    // wire [7:0] b_edge = { s_edge_data >> 2};
    wire [7:0] r_edge_mem = s_edge_rd_data;
    wire [7:0] g_edge_mem = s_edge_rd_data;
    wire [7:0] b_edge_mem = s_edge_rd_data;
    wire [7:0] r_grey = { s_gray_data [7:3], 3'b000};
    wire [7:0] g_grey = { s_gray_data [7:2], 2'b000};
    wire [7:0] b_grey = { s_gray_data [7:3], 3'b000};
    wire [7:0] r_color = { s_fb_rd_data [15:11], 3'b000};
    wire [7:0] g_color = { s_fb_rd_data [10:5], 2'b000};
    wire [7:0] b_color = { s_fb_rd_data [4:0], 3'b000};

    always_comb begin
        int v_shift_index;
        v_shift_index = 0;
        // case(s_switch)
        // case((s_rd_x>>5)+(s_rd_x>>3))
        if (s_rd_x < 40) begin
            o_data [2] = r_color;
            o_data [1] = g_color;
            o_data [0] = b_color;
        end else if (s_rd_x < 80) begin
            o_data [2] = r_grey;
            o_data [1] = g_grey;
            o_data [0] = b_grey;
        end else if (s_rd_x < 120) begin
            o_data [2] = r_edge_mem;
            o_data [1] = g_edge_mem;
            o_data [0] = b_edge_mem;
        end else begin
            o_data [2] = r_edge_mem;
            o_data [1] = g_edge_mem;
            o_data [0] = b_edge_mem;
        end
        o_de = s_shift_de[v_shift_index];
        o_vsync = s_shift_vsync[v_shift_index];
        o_hsync = s_shift_hsync[v_shift_index];
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_switch <= '0;
        end else begin
            if (i_toggle) s_switch <= s_switch + 1'b1;
        end
    end

    vga_gen inst_vga_gen (
      .i_clk_pixel (i_clk),
      .i_rst       (i_rst),
      .o_hsync     (s_hsync),
      .o_vsync     (s_vsync),
      .o_data_en   (s_de),
      .o_data_test (),
      .o_frame(s_frame),
      .o_line(),
      .o_x_pos(vga_x_pos),
      .o_y_pos(vga_y_pos)
    );
endmodule


