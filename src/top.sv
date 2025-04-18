`default_nettype none
// `include "build/clk1.v"
// `include "build/clk2.v"
module top (
    input logic clk_25mhz,
    input logic [6:0] btn,
    output logic [7:0] led,
    output logic gpdi_dp[4]//
    // output logic gpdi_dn[4]
);
    logic s_clk;
    logic s_rst;
    logic s_clk_pixel;
    logic s_clk_ddr;
    logic s_clk_sdr;
    logic s_clk_shift;

    localparam bit p_ddr_mode = 0;
    assign s_clk_shift = (p_ddr_mode) ? s_clk_ddr : s_clk_sdr;
    assign s_clk = clk_25mhz;
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
      .o_data      (s_colors)
    );

    // logic s_gpdi [4];
    // assign gpdi_dp[0] = s_gpdi [0];
    // assign gpdi_dp[1] = s_gpdi [1];
    // assign gpdi_dp[2] = s_gpdi [2];
    // assign gpdi_dp[3] = s_gpdi [3];
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
      .o_data_p    (gpdi_dp),
      .o_data_n    ()
      // .o_data_n    (gpdi_dn[4])
    );


    // assign s_clk_pixel = clk_25mhz;
    assign led[7:2] = '0;
    clk1 inst_clk_gen_sdr (
      .clkin(clk_25mhz),
      .clkout0(s_clk_sdr), //250
      .locked(led[0])
      );
    clk2 inst_clk_gen_ddr (
      .clkin(clk_25mhz),
      .clkout0(s_clk_ddr), //125
      .locked(led[1])
      );
endmodule


    // blinky inst_blink(
    //   .i_clk(s_clk),
    //   .i_btn(btn),
    //   .o_led(led)
    // );
