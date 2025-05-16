`default_nettype none
`timescale 1ns / 1ps

import package_cam::*;
import package_i2c::*;

module top #(
    localparam bit p_ddr_mode = 1, //works for both!
    localparam int p_num_states = 4
  ) (
    input logic clk_25mhz,
    input logic [6:0] btn,
    output logic [7:0] led,
    output logic [3:0] gpdi_dp,

    inout gp0,gn0, //I2C Pins
    input gp1,gp2,gp3,gp4,gp5,gp6,
    input gn1,    gn3,gn4,gn5,gn6,
    output    gn2, //clock in to cam
    output gp13,gp12, //cam reset and power
    //Logic analyzer pins
    output gp14,gp15,gp16,gp17,gp18,gp19,gp20,
    output gn14,gn15,gn16,gn17,gn18,gn19,gn20,

    output gn27,gp27
    
);
    logic s_clk_pixel, s_clk_shift, s_clk_sys;
    logic s_rst;
    logic [6:0] s_btn_trig;
    t_cam_signals s_camera;
    assign s_clk_pixel = s_clk_sys;
    assign s_rst = ~btn[0]; //ignore the debouce for btn[0]

    // t_i2c_cmd o_data;
    // assign o_data = 
    //   '{we:s_btn_trig[4]|s_btn_trig[6], sccb_mode:1, addr_slave:'h21, addr_reg:'h1E, burst_num:'d0}; 

    assign gn27 = s_btn_trig[4];
    assign gp27 = btn[4];

    logic s_cmd_valid, s_cmd_ready;
    t_i2c_cmd s_cmd_data;
    logic [7:0] s_wr_data;
    logic [7:0] s_rom_addr;
    logic [15:0] s_rom_data;
    i2c_rom_cmd_parser #(
      .p_sccb_mode      (1),
      .p_slave_addr     ('h21),
      .p_wr_mode        (1),
      .p_rom_addr_width (8)
    ) inst_i2c_rom_cmd_parser (
      .i_clk       (s_clk_sys),
      .i_rst       (s_rst),
      .i_start     (s_btn_trig[4]),
      .o_addr      (s_rom_addr),
      .i_data      (s_rom_data),
      .o_done      (led[0]),
      .o_cmd_valid (s_cmd_valid),
      .o_cmd_data  (s_cmd_data),
      .o_wr_data   (s_wr_data),
      .i_cmd_ready (s_cmd_ready)
    );

    ov7670_rom_sync inst_ov7670_config_rom (
      .clk (s_clk_sys),
      .addr(s_rom_addr),
      .data(s_rom_data)
    );

    i2c_master_wrapper #(.CMD_FIFO(0)) inst_i2c_master_wrapper (
      .i_clk(s_clk_sys),
      .i_rst(s_rst),
      .i_enable(1'b1),

      .i_cmd_fifo_valid(s_cmd_valid),
      .i_cmd_fifo_data(s_cmd_data),
      .o_cmd_fifo_ready(s_cmd_ready),

      .i_wr_fifo_valid(s_cmd_valid),
      .i_wr_fifo_data(s_wr_data),
      .o_wr_fifo_ready(),

      .o_rd_fifo_valid(),
      .o_rd_fifo_data(led[7:1]),
      .i_rd_fifo_ready(),

      .b_sda(gn0),
      .b_scl(gp0)
      // .b_sda(s_camera.sda),
      // .b_scl(s_camera.scl)
    );


    //CAMERA -------------------------------------------------------
    //camera inputs
    assign s_camera.clk_in = s_clk_pixel; //input
    // assign s_camera.rst = 1'b1; //reset active low
    assign s_camera.rst = ~s_rst; //reset active low
    assign s_camera.power_down = 1'b0;
    assign gn2 = s_camera.clk_in;
    assign gp13 = s_camera.rst;
    assign gp12 = s_camera.power_down;

    //camera outputs
    assign s_camera.sda = gn0;
    assign s_camera.scl = gp0;
    assign s_camera.vsync = gp1;
    assign s_camera.href = gn1;
    assign s_camera.clk_pixel = gp2;
    assign s_camera.data[7] = gp3;
    assign s_camera.data[5] = gp4;
    assign s_camera.data[3] = gp5;
    assign s_camera.data[1] = gp6;
    assign s_camera.data[6] = gn3;
    assign s_camera.data[4] = gn4;
    assign s_camera.data[2] = gn5;
    assign s_camera.data[0] = gn6;

    // assign led[7:1] = s_camera.data[7:1]; //LA OV Data lines
    // assign led[0] = s_camera.href;
    //Logic analyzer debug
    assign gp14 = s_camera.sda; //LA i2c
    assign gn14 = s_camera.scl; //LA i2c
    assign gp15 = s_camera.vsync;
    assign gn15 = s_camera.href;
    assign gn16 = s_camera.clk_pixel;
    assign gp16 = s_camera.clk_in;
    assign gp17 = s_camera.data[7]; //LA OV Data lines
    assign gp18 = s_camera.data[6]; //LA OV Data lines
    assign gp19 = s_camera.data[5]; //LA OV Data lines
    assign gp20 = s_camera.data[4]; //LA OV Data lines
    assign gn17 = s_camera.data[3]; //LA OV Data lines
    assign gn18 = s_camera.data[2]; //LA OV Data lines
    assign gn19 = s_camera.data[1]; //LA OV Data lines
    assign gn20 = s_camera.data[0]; //LA OV Data lines
    // assign gp17 = led[7]; //LA OV Data lines
    // assign gp18 = led[6]; //LA OV Data lines
    // assign gp19 = led[5]; //LA OV Data lines
    // assign gp20 = led[4]; //LA OV Data lines
    // assign gn17 = led[3]; //LA OV Data lines
    // assign gn18 = led[2]; //LA OV Data lines
    // assign gn19 = led[1]; //LA OV Data lines
    // assign gn20 = led[0]; //LA OV Data lines

    logic [p_num_states-1:0] s_demo_state;
    logic s_hsync;
    logic s_vsync;
    logic s_de;
    logic s_frame;
    logic s_line;
    logic [7:0] s_colors [3];
    logic [7:0] s_colors_test [3];
    logic [7:0] s_colors_cam[3];
    logic [7:0] s_colors3 [3];
    logic signed [15:0] s_x_pos;
    logic signed [15:0] s_y_pos;

    camera_top #(
      .p_scaler(2)
      )inst_camera_top (
      .i_clk(s_clk_pixel),
      .i_rst(s_rst),
      .i_camera(s_camera),
      .i_frame(s_frame),
      .i_line(s_line),
      .i_x_pos(s_x_pos),
      .i_y_pos(s_y_pos),
      .led(),
      .o_data(s_colors)
    );

    logic [15:0] s_cam_out;
    logic [7:0] R;
    logic [7:0] G;
    logic [7:0] B;

    assign R = { s_cam_out[15:11], 3'b000};
    assign G = { s_cam_out[10:5], 2'b00};
    assign B = { s_cam_out[4:0] , 3'b000};
    logic s_read_valid;
    logic [9:0] s_wr_row, s_wr_col;
    camera_read inst_camera_read (
      .i_clk       (s_clk_pixel),
      .i_rst       (s_rst),
      .i_vsync     (s_camera.vsync),
      .i_href     (s_camera.href),
      .i_data(s_camera.data),
      .o_valid(s_read_valid),
      .o_data(s_cam_out),
      .o_frame_done(),
      .o_row(s_wr_row),
      .o_col(s_wr_col)
      );

    // assign gn27 = s_read_valid;
    // assign led[7:1] = G; //LA OV Data lines
    // assign led[0] = s_read_valid;
    // assign s_colors3[0] = (s_read_valid) ? B : '0;
    // assign s_colors3[1] = (s_read_valid) ? G : '0;
    // assign s_colors3[2] = (s_read_valid) ? R : '0;
    // assign s_colors3[2] = s_colors_test[2];
    // assign s_colors3[2] = R;
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
      .o_data_test (s_colors_test),
      .o_frame(s_frame),
      .o_line(s_line),
      .o_x_pos(s_x_pos),
      .o_y_pos(s_y_pos)
    );

    //assign the pixel clock to output
    assign gpdi_dp[3] = s_clk_pixel;
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


    // assign led[7] = s_clk_pixel;
    // assign led[6] = s_line;
    // assign led[6] = 0;
    // assign led[5] = s_btn_trig[1];
    // assign led[4] = s_rst;
    // assign led[3] = s_vsync;
    // assign led[2] = s_hsync;
    // assign led[1] = 0;
    // assign led[3:0] = s_demo_state;

    generate
      for(genvar i = 0; i < $bits(btn); i++) begin : gen_btn_debounce
        debounce inst_debounce (
          .i_clk(s_clk_sys),
          .i_trig(btn[i]),
          .o_trig(s_btn_trig[i])
        );

      end
    endgenerate
    generate
      if(p_ddr_mode) begin : gen_ddr_pll
        clk2 inst_clk_gen_ddr (
          .clkin(clk_25mhz),
          .clkout0(s_clk_shift), //125
          .clkout1(s_clk_sys), //25
          .locked()
          );
      end else begin : gen_sdr_pll
        clk1 inst_clk_gen_sdr (
          .clkin(clk_25mhz),
          .clkout0(s_clk_shift), //250
          .clkout1(s_clk_sys), //25
          .locked()
          );
      end
    endgenerate

    demo_switch #(
      .p_states(p_num_states)
    )inst_demo_switch (
      .i_clk(s_clk_sys),
      .i_rst(s_rst),
      .i_next(s_btn_trig[1]),
      .i_prev(s_btn_trig[2]),
      .o_state(s_demo_state)
    );

endmodule
