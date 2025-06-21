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
    input logic [3:0] sw,
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

    //SDRAM Interface
    output wire        sdram_clk,
    output wire        sdram_cke,
    output wire        sdram_csn,
    output wire        sdram_wen,
    output wire        sdram_rasn,
    output wire        sdram_casn,
    output wire [12:0] sdram_a,
    output wire [ 1:0] sdram_ba,
    output wire [ 1:0] sdram_dqm,
    inout  wire [15:0] sdram_d
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


    logic [9:0] row,col,row_max,col_max;

    logic s_cam_done;
    logic s_sdram_done;

    logic signed [16-1:0] vga_x_pos;
    logic signed [16-1:0] vga_y_pos;

    //--------------------------------------------------------------------------------
    // CAMERA CONFIG OV7670
    //--------------------------------------------------------------------------------
    logic s_cmd_valid;
    logic s_cmd_ready;
    t_i2c_cmd s_cmd_data;
    logic [7:0] s_wr_data;
    logic [7:0] s_rom_addr;
    logic [15:0] s_rom_data;
    i2c_rom_cmd_parser #(
      .p_sccb_mode      (1),
      .p_slave_addr     ('h21),
      .p_wr_mode        (1),
      .p_auto_init      (0), 
      .p_rom_addr_width (8)
    ) inst_i2c_rom_cmd_parser (
      .i_clk       (s_clk_sys),
      .i_rst       (s_rst),
      .i_start     (s_btn_trig[3]),
      .o_addr      (s_rom_addr),
      .i_data      (s_rom_data),
      .o_done      (s_cam_done),
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

      .i_rd_fifo_ready(1'b0),

      .b_sda(gn0),
      .b_scl(gp0)
    );

    //--------------------------------------------------------------------------------
    // MLX TOP
    //--------------------------------------------------------------------------------
    // localparam c_mlx_addrw = $clog2(32*24+64);
    // logic                   i_fb_rd_valid;
    // logic [c_mlx_addrw-1:0] i_fb_rd_addr;
    // logic            [7:0] o_fb_rd_data;
    //
    //
    // mlx90640_top #(
    //   // .p_delay_const()
    // ) inst_mlx (
    //   .i_clk(s_clk_sys),
    //   .i_rst(s_rst),
    //   .i_trig(s_btn_trig[6]),
    //   // .i_trig(s_cam_done | s_btn_trig[6]),
    //   // .o_debug(led),
    //   .i_fb_rd_valid,
    //   .i_fb_rd_addr,
    //   .o_fb_rd_data,
    //   .b_sda(gn0),
    //   .b_scl(gp0)
    // );

    //--------------------------------------------------------------------------------
    // SDRAM TOP
    //--------------------------------------------------------------------------------
    logic [7:0] s_colors_test [3];
    logic          s_wr_fifo_valid;
    logic [16-1:0] s_wr_fifo_data;
    logic          s_wr_fifo_ready;

    logic          s_rd_fifo_valid;
    logic [16-1:0] s_rd_fifo_data;
    logic          s_rd_fifo_ready;

    logic [7:0] s_debug_status;
    logic s_sdram_init_done;

    logic s_frame;

    

    logic [15:0] s_counter;
    always_ff @(posedge s_clk_sys) begin
      if (s_rst) begin
        s_counter <= '0;
      end else begin
        if(s_wr_fifo_ready&s_wr_fifo_valid) s_counter <= s_counter + 1;
      end
    end

    sdram_top #(
      .p_sdram_dataw (16)
    ) inst_sdram_top (
      .i_clk           (s_clk_sys),
      .i_rst           (s_rst),

      .i_clk_wr_fifo   (s_camera.clk_pixel),
      .i_wr_fifo_valid (s_wr_fifo_valid),
      // .i_wr_fifo_data  (s_wr_fifo_data),
      .i_wr_fifo_data  (col[6:0]<<5),
      // .i_wr_fifo_data  (s_counter),
      // .i_wr_fifo_data  (row[4:0]),
      // .i_wr_fifo_valid ('1),
      // .i_wr_fifo_data  ({5'b11111,11'b0}),
      // .i_wr_fifo_data  ({5'b11111}),
      .o_wr_fifo_ready (s_wr_fifo_ready),

      .o_rd_fifo_valid (s_rd_fifo_valid),
      .o_rd_fifo_data  (s_rd_fifo_data),
      .i_rd_fifo_ready (s_rd_fifo_ready),

      // .i_new_frame     (s_frame |s_btn_trig[1]),
      .i_new_frame     (s_frame),

      .o_sdram_clk     (sdram_clk),
      .o_sdram_cke     (sdram_cke),
      .o_sdram_we_n    (sdram_wen),
      .o_sdram_cs_n    (sdram_csn),
      .o_sdram_ras_n   (sdram_rasn),
      .o_sdram_cas_n   (sdram_casn),
      .o_sdram_addr    (sdram_a),
      .o_sdram_ba      (sdram_ba),
      .o_sdram_dqm     (sdram_dqm),
      .b_sdram_dq      (sdram_d),

      .o_sdram_initialized(s_sdram_init_done),

      .i_debug_trig    (s_btn_trig[2:1]),
      // .i_debug_trig    ({btn[6],s_btn_trig[1]}),
      .o_debug_status  (s_debug_status)

    );

    // logic [7:0] s_sdram_done_sync;
    // assign s_sdram_done = s_sdram_done_sync[7];
    // always_ff @(posedge s_clk_sys) begin
    //     if (s_rst) s_sdram_done_sync <= '0;
    //     else s_sdram_done_sync <= {s_sdram_done_sync[6:0], s_sdram_init_done};
    // end

    //--------------------------------------------------------------------------------
    // CAMERA WIRING
    //--------------------------------------------------------------------------------
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

    //--------------------------------------------------------------------------------
    // LOGIC ANALYZER DEBUGGING
    //--------------------------------------------------------------------------------
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


    //--------------------------------------------------------------------------------
    // OV7670 CAMERA DATA READ/CAPTURE
    //--------------------------------------------------------------------------------
 
    // assign led = row[8:1];
    // assign led = row>>0;
    // assign led = row_max>>2;
    // assign led = col>>0;
    // assign led = {col, s_camera.clk_pixel,s_camera.vsync, s_camera.href, s_rst, s_wr_fifo_valid};
    // assign led = col_max>>2;
    // assign led = {|row[9:6],row[5:0],s_wr_fifo_valid};
    //
    // always_ff @(posedge s_camera.clk_pixel) led <= col_max>>2;
    camera_read inst_camera_read (
      .i_clk       (s_camera.clk_pixel), //data is run on the pixel clock from the camera
      .i_rst       (s_rst),
      .i_vsync     (s_camera.vsync),
      .i_href      (s_camera.href),
      .i_data      (s_camera.data),
      .o_valid     (s_wr_fifo_valid),
      .o_data      (s_wr_fifo_data),
      .o_row_max   (row_max),
      .o_col_max   (col_max),
      .o_row       (row),
      .o_col       (col)
    );

    //--------------------------------------------------------------------------------
    // VGA FRAME GENERATION
    //--------------------------------------------------------------------------------
    logic s_hsync;
    logic s_vsync;
    logic s_de;
    logic s_line;
    logic [7:0] s_colors [3];

    logic s_vga_enable;

    always_ff @(posedge s_clk_sys) begin
      if(s_rst) s_vga_enable <= '0;
      else if (s_btn_trig[5] | s_rd_fifo_valid) s_vga_enable <= 1'b1;
      // else if (s_btn_trig[5] ) s_vga_enable <= 1'b1;
    end
    vga_gen inst_vga_gen (
      .i_clk_pixel (s_clk_sys),
      .i_rst       (s_rst | ~s_vga_enable),
      .o_hsync     (s_hsync),
      .o_vsync     (s_vsync),
      .o_frame     (s_frame),
      .o_line      (s_line),
      .o_data_en   (s_de),
      .o_data_test (s_colors_test),
      .o_x_pos     (vga_x_pos),
      .o_y_pos     (vga_y_pos)
    );



    logic [$clog2(640*480):0] s_pixel_count;
    logic s_update_init;
    logic s_update_frame;
    wire x_de = ~vga_x_pos[15];
    wire y_de = ~vga_y_pos[15];
    assign s_rd_fifo_ready = s_de;
    // assign s_rd_fifo_ready = s_de & x_de & y_de & (vga_x_pos < 512) & (vga_y_pos < 400);
    // assign s_rd_fifo_ready = s_de & ((vga_x_pos >= 512) & (vga_y_pos == 0)) & y_de & x_de;




    // always_ff @(posedge s_clk_sys) s_rd_fifo_ready <= s_de;

    // always_ff @(posedge s_clk_sys) begin
    //
    //   if (s_rst) begin
    //     s_update_frame <= '0;
    //     s_update_init <= '0;
    //     // s_rd_fifo_ready <= '0;
    //   end
    //   else begin
    //     if (s_btn_trig[5]) s_update_init <= '1;
    //
    //     if (s_frame) begin
    //       s_pixel_count <= '0;
    //       s_update_init <= '0;
    //       s_update_frame <= s_update_init;
    //       // if (s_update_init) s_update_frame <= '1;
    //     end
    //
    //     // if (s_pixel_count <= 'd600) begin
    //     //   s_update_frame <= '0;
    //     //   s_update_init <= '0;
    //     // end
    //     if (s_de) s_pixel_count <= s_pixel_count + 1'b1;
    //     // s_rd_fifo_ready <= s_de & (s_pixel_count <= 'd600);
    //     //
    //     // s_rd_fifo_ready <= s_de & s_update_frame;
    //     // s_rd_fifo_ready <= s_de;
    //     // s_rd_fifo_ready <= s_de & (s_pixel_count <= 'd600);
    //   end
    //
    //
    // end

    wire [7:0] r_color = { s_rd_fifo_data [15:11], 3'b000};
    wire [7:0] g_color = { s_rd_fifo_data [10:5], 2'b000};
    wire [7:0] b_color = { s_rd_fifo_data [4:0], 3'b000};
    assign s_colors[2] = r_color;
    assign s_colors[1] = g_color;
    assign s_colors[0] = b_color;
    // assign s_colors[2] = '0;
    // assign s_colors[1] = '0;
    // assign s_colors[0] = vga_y_pos[4:0]<<3;

    // assign led =
    //   s_debug_status;
      // {s_wr_fifo_data ,s_wr_fifo_valid};
      // // {s_wr_fifo_valid, s_wr_fifo_ready,s_debug_status[5:0] };
      // {s_wr_fifo_valid, s_wr_fifo_ready, 1'b0, s_rd_fifo_valid, s_rd_fifo_ready,s_de,s_vsync,s_hsync};

      assign led = {s_debug_status};

    // assign led = {s_debug_status, s_rd_fifo_valid, s_rd_fifo_ready, s_frame};

    logic [16:0] s_count, s_count_max;
    logic s_de_latch;
    // assign led = s_count_max >> 0;

    always_ff @(posedge s_clk_sys) begin
      s_de_latch <= s_de;
      if (s_rst) begin
        s_count <= '0;
        s_count_max <= '0;
      end else begin
        if(s_frame) begin
          s_count <= '0;
          if (s_count > s_count_max) s_count_max <= s_count;
        end
        else if(~s_de_latch & s_de) s_count <= s_count + 1;
        // else if (s_line) begin
        //   s_count <= '0;
        //   if (s_count > s_count_max) s_count_max <= s_count;
        // end
        // else if (s_de) s_count <= s_count + 1;
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
      .i_data      (s_colors),
      .o_data_p    (gpdi_dp[2:0])
    );

    //--------------------------------------------------------------------------------
    // BUTTON DEBOUNCING AND PLL CLOCK SETUPS
    //--------------------------------------------------------------------------------
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
        clk_vga_ddr inst_clk_gen_ddr (
          .clkin(clk_25mhz),
          .clkout0(s_clk_shift), //125
          .clkout1(s_clk_sys), //25
          .locked()
          );
      end else begin : gen_sdr_pll
        clk_vga_sdr inst_clk_gen_sdr (
          .clkin(clk_25mhz),
          .clkout0(s_clk_shift), //250
          .clkout1(s_clk_sys), //25
          .locked()
          );
      end
    endgenerate
endmodule
