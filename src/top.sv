module top (
    input logic clk_25mhz,
    input logic [6:0] btn,
    output logic [7:0] led
);
    logic s_clk;
    logic s_rst;

    assign s_clk = clk_25mhz;
    assign s_rst = btn[1];

    genvar i;    

    generate
      for(i = 0; i < 3; i++) begin
        logic [9:0] s_encoded;
        tmds_gen inst_tmds_gen (
          .i_clk(s_clk),
          .i_rst(s_rst),
          .i_data(),
          .i_control_data(),
          .i_blanking(),
          .o_encoded(s_encoded)
          );

          fake_differential #(
            .c_word_width($bits(s_encoded))
            ) inst_diff_out (
              .i_clk(s_clk),
              .i_rst(s_rst),
              .i_data(s_encoded),
              .o_data_p(gpdi_dp[i]),
              .o_data_n(gpdi_dn[i])
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


