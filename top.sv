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

    inout wire gp0,gn0, //I2C Pins
    input gp1,gp2,gp3,gp4,gp5,gp6,
    input gn1,    gn3,gn4,gn5,gn6,
    output    gn2, //clock in to cam
    output gp13,gp12, //cam reset and power
    //Logic analyzer pins
    output gp14,gp15,gp16,gp17,gp18,gp19,gp20,
    output gn14,gn15,gn16,gn17,gn18,gn19,gn20,

    output gn27,gp27
    
);
    //unsupported by verilator :/
    // alias sda = gn0;
    // alias scl = gp0;

    logic s_clk_pixel, s_clk_shift, s_clk_sys;
    logic s_rst;
    logic [6:0] s_btn_trig;
    t_cam_signals s_camera;
    assign s_clk_pixel = s_clk_sys;
    assign s_rst = ~btn[0]; //ignore the debouce for btn[0]

    // t_i2c_cmd o_data;
    // assign o_data = 
    //   '{we:s_btn_trig[4]|s_btn_trig[6], sccb_mode:1, addr_slave:'h21, addr_reg:'h1E, burst_num:'d0}; 

    assign gn27 = led[7];

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
      // .o_done      (led[0]),
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

    i2c_master_wrapper_8b #(.CMD_FIFO(0)) inst_i2c_master_8b_wrapper (
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
      // .o_rd_fifo_data(led[7:1]),
      .i_rd_fifo_ready(),

      .b_sda(gn0),
      .b_scl(gp0)
      // .b_sda(s_camera.sda),
      // .b_scl(s_camera.scl)
    );

    //--------------------------------------------------------------------------------
    //MLX TOP
    //--------------------------------------------------------------------------------
    localparam c_mlx_addrw = $clog2(32*24+64);
    logic                   i_fb_rd_valid;
    logic [c_mlx_addrw-1:0] i_fb_rd_addr;
    logic            [16:0] o_fb_rd_data;

    logic signed [16-1:0] vga_x_pos;
    logic signed [16-1:0] vga_y_pos;

    mlx90640_top #(
      // .p_delay_const()
    ) inst_mlx (
      .i_clk(s_clk_sys),
      .i_rst(s_rst),
      .i_trig(s_btn_trig[6]),
      .o_debug(led),
      .i_fb_rd_valid,
      .i_fb_rd_addr,
      .o_fb_rd_data,
      .b_sda(gn0),
      .b_scl(gp0)
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
    // assign gp17 = s_camera.data[7]; //LA OV Data lines
    // assign gp18 = s_camera.data[6]; //LA OV Data lines
    // assign gp19 = s_camera.data[5]; //LA OV Data lines
    // assign gp20 = s_camera.data[4]; //LA OV Data lines
    // assign gn17 = s_camera.data[3]; //LA OV Data lines
    // assign gn18 = s_camera.data[2]; //LA OV Data lines
    // assign gn19 = s_camera.data[1]; //LA OV Data lines
    // assign gn20 = s_camera.data[0]; //LA OV Data lines
    assign gp17 = led[7]; //LA OV Data lines
    assign gp18 = led[6]; //LA OV Data lines
    assign gp19 = led[5]; //LA OV Data lines
    assign gp20 = led[4]; //LA OV Data lines
    assign gn17 = led[3]; //LA OV Data lines
    assign gn18 = led[2]; //LA OV Data lines
    assign gn19 = led[1]; //LA OV Data lines
    assign gn20 = led[0]; //LA OV Data lines

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
      // .p_scaler(2)
      )inst_camera_top (
      .i_clk(s_clk_pixel),
      .i_rst(s_rst),
      .i_camera(s_camera),
      .o_hsync (s_hsync),
      .o_vsync (s_vsync),
      .o_de(s_de),
      // .led(led),
      .vga_x_pos,
      .vga_y_pos,
      .i_toggle(s_btn_trig[3]),
      .o_data(s_colors)
    );

    // assign s_colors3[0] = s_colors[0];
    // assign s_colors3[1] = s_colors[1];
    // assign s_colors3[2] = s_colors[2];
    // assign s_colors3[0] = o_fb_rd_data>>1;
    // assign s_colors3[1] = o_fb_rd_data>>1;
    // assign s_colors3[2] = o_fb_rd_data>>1;

    // assign i_fb_rd_addr = vga_x_pos/20 + vga_y_pos/20;
    // assign i_fb_rd_valid = 1'b1;
    always_comb begin
      logic [15:0] v_x_pos, v_y_pos;
      v_x_pos = vga_x_pos>>3;
      v_y_pos = vga_y_pos>>3;

      //32-x for v flip
      i_fb_rd_addr = v_y_pos*'d32 + (32-v_x_pos);
      i_fb_rd_valid = 1'b1;

      if ((v_x_pos < 32) & (v_y_pos < 24)) begin
        s_colors3[0] = o_fb_rd_data>>1;
        s_colors3[1] = o_fb_rd_data>>1;
        s_colors3[2] = o_fb_rd_data>>1;
      end else begin
        s_colors3[0] = s_colors[0];
        s_colors3[1] = s_colors[1];
        s_colors3[2] = s_colors[2];
      end
    end

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
