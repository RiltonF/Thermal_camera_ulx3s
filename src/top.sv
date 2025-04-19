`default_nettype none
module top (
    input logic clk_25mhz,
    input logic [6:0] btn,
    output logic [7:0] led,
    output logic [3:0] gpdi_dp
);
    logic s_rst;
    logic s_clk_pixel;
    logic s_clk_ddr;
    logic s_clk_sdr;
    logic s_clk_shift;

    localparam bit p_ddr_mode = 1;
    assign s_clk_shift = (p_ddr_mode) ? s_clk_ddr : s_clk_sdr;
    // assign s_clk_pixel = clk_25mhz;
    assign s_rst = btn[1];

    logic s_hsync;
    logic s_vsync;
    logic s_blank;
    logic [7:0] s_colors [3];

    vga_gen inst_vga_gen (
      .i_clk_pixel (s_clk_pixel),
      .i_rst       (s_rst),
      .o_hsync     (s_hsync),
      .o_vsync     (s_vsync),
      .o_blank     (s_blank),
      .o_data_test (s_colors)
    );

    vga_to_dvi #(
      .p_ddr_mode (p_ddr_mode)
    ) inst_dvi (
      .i_clk_pixel (s_clk_pixel),
      .i_clk_shift (s_clk_shift),
      .i_rst       (s_rst),
      .i_hsync     (s_hsync),
      .i_vsync     (s_vsync),
      .i_blank     (s_blank),
      .i_data      (s_colors),
      .o_data_p    (gpdi_dp[2:0])
    );

    //assign the pixel clock to output
    assign gpdi_dp[3] = s_clk_pixel;

    assign led[7] = s_clk_pixel;
    assign led[6] = s_blank;
    assign led[5] = s_blank;
    assign led[4] = s_rst;
    assign led[3] = s_vsync;
    assign led[2] = s_hsync;

    clk1 inst_clk_gen_sdr (
      .clkin(clk_25mhz),
      .clkout0(s_clk_sdr), //250
      .locked(led[0])
      );
    clk2 inst_clk_gen_ddr (
      .clkin(clk_25mhz),
      .clkout1(s_clk_pixel), //25
      .clkout0(s_clk_ddr), //125
      .locked(led[1])
      );


endmodule
