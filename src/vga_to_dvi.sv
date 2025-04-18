`default_nettype none
module vga_to_dvi #(
    parameter bit p_ddr_mode = 1'b0
  )(
    input  logic i_clk_pixel,
    input  logic i_clk_shift,
    input  logic i_rst,
    input  logic i_hsync,
    input  logic i_vsync,
    input  logic i_blank,
    input  logic [7:0] i_data [3], // RGB data
    output logic o_data_p [4], // [clock, red, green, blue]
    output logic o_data_n [4]
);
    logic [1:0] s_clk_tmds;

    //generated the tmds clock output based on mode
    generate
      logic s_shift_bit;
      if (p_ddr_mode) begin
        ODDRX1F inst_ddr_shift (
          .D0(s_clk_tmds[0]),
          .D1(s_clk_tmds[1]),
          .Q(s_shift_bit),
          .SCLK(i_clk_shift),
          .RST(i_rst)
        );

        assign o_data_p[3] = s_shift_bit;
        assign o_data_n[3] = ~s_shift_bit;

      end else begin
        //only using first bit in sdr mode
        assign s_shift_bit = s_clk_tmds[0];

        fake_differential inst_diff_out (
          .i_clk(i_clk_shift),
          .i_rst(i_rst),
          .i_data(s_shift_bit),
          .o_data_p(o_data_p[3]),
          .o_data_n(o_data_n[3])
        );
      end
    endgenerate

    //generate the rgb colors based on mode
    generate
      for (genvar i = 0; i < 3; i++) begin
        logic [9:0] s_encoded;
        logic [1:0] s_shift_bits, s_clk_serial;
        logic s_shift_bit;
        tmds_gen inst_tmds_gen (
          .i_clk(i_clk_pixel),
          .i_rst(i_rst),
          .i_data(i_data[i]),
          .i_control_data({i_vsync, i_hsync}), //only set one or all colors? idk...
          .i_blanking(i_blank),
          .o_encoded(s_encoded)
        );

        serializer #(
          .p_ddr_mode   (p_ddr_mode) // sdr mode
        ) inst_serializer (
          .i_clk_data  (i_clk_pixel),
          .i_clk_shift (i_clk_shift),
          .i_rst       (i_rst),
          .i_data      (s_encoded),
          .o_data      (s_shift_bits),
          .o_clk       (s_clk_serial)
        );

        if (i == 3) assign s_clk_tmds = s_clk_serial;

        if (p_ddr_mode) begin
          ODDRX1F inst_ddr_shift (
            .D0(s_shift_bits[0]),
            .D1(s_shift_bits[1]),
            .Q(s_shift_bit),
            .SCLK(i_clk_shift),
            .RST(i_rst)
          );

          assign o_data_p[i] = s_shift_bit;
          assign o_data_n[i] = ~s_shift_bit;

        end else begin
          //only using first bit in sdr mode
          assign s_shift_bit = s_shift_bits[0];

          fake_differential inst_diff_out (
            .i_clk(i_clk_shift),
            .i_rst(i_rst),
            .i_data(s_shift_bit),
            .o_data_p(o_data_p[i]),
            .o_data_n(o_data_n[i])
          );
        end

      end
    endgenerate
endmodule


