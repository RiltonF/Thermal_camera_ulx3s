// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "vga_gen.sv"
`timescale 1 ns / 100 ps

module tb_vga_gen();

    `SVUT_SETUP

    logic clk_pixel = 1;
    logic i_rst;
    logic o_hsync;
    logic o_vsync;
    logic o_blank;
    logic [7:0] o_data [3];

    vga_gen 
    dut 
    (
    .i_clk_pixel (clk_pixel),
    .i_rst       (i_rst),
    .o_hsync     (o_hsync),
    .o_vsync     (o_vsync),
    .o_data_en(o_blank),
    .o_data      (o_data)
    );

    always #(5ns) clk_pixel= ~clk_pixel; // verilator lint_off STMTDLY

    // To create a clock:
    // initial aclk = 0;
    // always #2 aclk = !aclk;

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
        i_rst = 1;
        #100ns;
        i_rst = 0;
    end
    endtask

    task teardown(msg="");
    begin
        // teardown() runs when a test ends
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")
    `UNIT_TEST("TESTCASE_NAME")
        #1;
        force dut.y_counter = 'd477;
        repeat (4) @(posedge clk_pixel);
        release dut.y_counter;
        repeat (200000) @(posedge clk_pixel);
        // #10000000ns;

        // Describe here the testcase scenario
        //
        // Because SVUT uses long nested macros, it's possible
        // some local variable declaration leads to compilation issue.
        // You should declare your variables after the IOs declaration to avoid that.

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
