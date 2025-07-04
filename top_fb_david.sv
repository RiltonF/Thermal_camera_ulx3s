`default_nettype none
`timescale 1ns / 1ps
module top_fb_david (
    input logic clk_25mhz,
    input logic [6:0] btn,
    output logic [7:0] led,
    output logic [3:0] gpdi_dp,
    output logic gp26
);
    localparam bit p_ddr_mode = 1; //works for both!
    logic s_rst;
    logic s_clk_pixel, s_clk_shift;
    logic s_clk_sdr_pixel, s_clk_ddr_pixel;
    logic s_clk_sdr, s_clk_ddr;

    assign s_clk_pixel = (p_ddr_mode) ? s_clk_ddr_pixel : s_clk_sdr_pixel;
    assign s_clk_shift = (p_ddr_mode) ? s_clk_ddr : s_clk_sdr;
    assign s_rst = btn[1];
    assign gp26 = s_clk_pixel;

    logic s_hsync;
    logic s_vsync;
    logic s_de;
    logic s_frame;
    logic s_line;
    logic [7:0] s_colors [3];
    logic [7:0] s_colors2 [3];
    logic [7:0] s_colors3 [3];
    logic signed [15:0] s_x_pos;
    logic signed [15:0] s_y_pos;

    framebuffer inst_framebuffer (
      .i_clk_pixel (s_clk_pixel),
      .i_rst       (s_rst),
      .i_frame(s_frame),
      .i_line(s_line),
      .i_x_pos(s_x_pos),
      .i_y_pos(s_y_pos),
      .debug_sig(led[2]),
      .o_data(s_colors)
    );

    assign s_colors3[0] = s_colors[0];
    assign s_colors3[1] = s_colors[1];
    assign s_colors3[2] = s_colors[2];
    // assign s_colors3[2] = s_colors2[2];

    vga_gen inst_vga_gen (
      .i_clk_pixel (s_clk_pixel),
      .i_rst       (s_rst),
      .o_hsync     (s_hsync),
      .o_vsync     (s_vsync),
      .o_data_en   (s_de),
      .o_data_test (s_colors2),
      .o_frame(s_frame),
      .o_line(s_line),
      .o_x_pos(s_x_pos),
      .o_y_pos(s_y_pos)
    );

    vga_to_dvi #(
      .p_ddr_mode (p_ddr_mode)
    ) inst_dvi (
      .i_clk_pixel (s_clk_pixel),
      .i_clk_shift (s_clk_shift),
      .i_rst       (s_rst),
      .i_hsync     (s_hsync),
      .i_vsync     (s_vsync),
      .i_blank     (~s_de),
      .i_data      (s_colors3),
      .o_data_p    (gpdi_dp[2:0])
    );

    //assign the pixel clock to output
    assign gpdi_dp[3] = s_clk_pixel;

    assign led[7] = s_clk_pixel;
    assign led[6] = s_line;
    assign led[5] = s_frame;
    assign led[4] = s_rst;
    assign led[3] = s_vsync;
    // assign led[2] = s_hsync;

    clk1 inst_clk_gen_sdr (
      .clkin(clk_25mhz),
      .clkout0(s_clk_sdr), //250
      .clkout1(s_clk_sdr_pixel), //25
      .locked(led[0])
      );
    clk2 inst_clk_gen_ddr (
      .clkin(clk_25mhz),
      .clkout0(s_clk_ddr), //125
      .clkout1(s_clk_ddr_pixel), //25
      .locked(led[1])
      );


endmodule
