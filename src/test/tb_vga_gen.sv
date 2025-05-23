// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "vga_gen.sv"
`timescale 1 ns / 100 ps

module tb_vga_gen();

    `SVUT_SETUP

    parameter int p_pixel_width       = 640;
    parameter int p_pixel_height      = 480;
    parameter int p_hsync_front_porch =  16;
    parameter int p_hsync_pulse       =  96;
    parameter int p_hsync_back_porch  =  48;
    parameter int p_vsync_front_porch =  10;
    parameter int p_vsync_pulse       =  2;
    parameter int p_vsync_back_porch  =  33;
    parameter bit p_hsync_polarity = 1;
    parameter bit p_vsync_polarity = 1;
    parameter int p_count_width = 16;

    logic clk=1;
    logic rst=1;
    logic o_hsync;
    logic o_vsync;
    logic o_data_en;
    logic o_frame;
    logic o_line;
    logic [7:0] o_data_test [3];
    logic signed [p_count_width-1:0] o_x_pos;
    logic signed [p_count_width-1:0] o_y_pos;

    vga_gen 
    #(
    .p_pixel_width    (p_pixel_width),
    .p_pixel_height   (p_pixel_height),
    .p_hsync_front_porch (p_hsync_front_porch),
    .p_hsync_pulse    (p_hsync_pulse),
    .p_hsync_back_porch (p_hsync_back_porch),
    .p_vsync_front_porch (p_vsync_front_porch),
    .p_vsync_pulse    (p_vsync_pulse),
    .p_vsync_back_porch (p_vsync_back_porch),
    .p_hsync_polarity (p_hsync_polarity),
    .p_vsync_polarity (p_vsync_polarity),
    .p_count_width    (p_count_width)
    )
    dut 
    (
    .i_clk_pixel (clk),
    .i_rst       (rst),
    .o_hsync     (o_hsync),
    .o_vsync     (o_vsync),
    .o_data_en   (o_data_en),
    .o_frame     (o_frame),
    .o_line      (o_line),
    .o_data_test,
    .o_x_pos     (o_x_pos),
    .o_y_pos     (o_y_pos)
    );

    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    //Clocks
    always #(5ns) clk= ~clk; // verilator lint_off STMTDLY

    // To dump data for visualization:
    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, tb_vga_gen);
    end

    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        // setup() runs when a test begins
        rst=1;
        wait_cycles(4);
        rst=0;
    end
    endtask

    task teardown(msg="");
    begin
        // teardown() runs when a test ends
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")

    `UNIT_TEST("TESTCASE_NAME")
        #1ns;
        wait(o_data_en);
        wait_cycles(640*20);
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
