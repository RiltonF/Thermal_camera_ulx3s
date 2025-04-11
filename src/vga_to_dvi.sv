module vga_to_dvi (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_hsync,
    input  logic i_vsync,
    input  logic i_blank,
    input  logic i_data [4],
    output logic o_data_p [4],
    output logic o_data_n [4]
);
    logic s_clk_pixel, s_clk_shift;

    assign s_clk_pixel = i_clk;

    genvar i;    

    generate
      for(i = 0; i < 3; i++) begin
        logic [9:0] s_encoded;
        tmds_gen inst_tmds_gen (
          .i_clk(s_clk),
          .i_rst(i_rst),
          .i_data(),
          .i_control_data(),
          .i_blanking(),
          .o_encoded(s_encoded)
          );

          fake_differential inst_diff_out (
            .i_clk(s_clk),
            .i_rst(i_rst),
            .i_data(s_encoded),
            .o_data_p(o_data_p[i]),
            .o_data_n(o_data_n[i])
            );
      end
    endgenerate
    

    blinky inst_blink(
      .i_clk(s_clk),
      .i_btn(btn),
      .o_led(led)
    );

    // clk0 inst_clk_gen (
    //   .clkin(clk_25mhz),
    //   // .clkout0(s_clk),
    //   // .clkout1(s_clk),
    //   .clkout2(s_clk),
    //   // .clkout3(s_clk),
    //   .locked()
    //   );

endmodule


