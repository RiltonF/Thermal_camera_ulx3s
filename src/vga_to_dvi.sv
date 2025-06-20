`default_nettype none
`timescale 1ns / 1ps
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
    output logic [2:0] o_data_p // [red, green, blue]
);
    //generate the rgb colors based on mode
    generate
      for (genvar i = 0; i < 3; i++) begin : gen_colors_dvi
        logic [9:0] s_encoded;
        logic [1:0] s_shift_bits, s_control_data;
        logic [7:0] s_data;
        assign s_control_data = (i == 2) ? {i_vsync, i_hsync} : 2'b0;

        assign s_data = (i_blank) ? '0 : i_data[i];
        tmds_gen inst_tmds_gen (
          .i_clk(i_clk_pixel),
          .i_rst(i_rst),
          .i_data(s_data),
          .i_control_data(s_control_data), //only set one or all colors? idk...
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
          .o_clk       ()
        );

        if (p_ddr_mode) begin : gen_ddr_primative
          ODDRX1F inst_ddr_shift (
            .D0(s_shift_bits[0]),
            .D1(s_shift_bits[1]),
            .Q(o_data_p[i]),
            .SCLK(i_clk_shift),
            .RST(i_rst)
          );

        end else begin
          //only using first bit in sdr mode
          assign o_data_p[i] = s_shift_bits[0];
        end
      end
    endgenerate
endmodule


