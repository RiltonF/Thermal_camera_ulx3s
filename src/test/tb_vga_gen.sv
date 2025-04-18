// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "vga_gen.sv"
`timescale 1 ns / 100 ps

module vga_gen_testbench();

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
    .o_blank     (o_blank),
    .o_data      (o_data)
    );

    always #(5ns) clk_pixel= ~clk_pixel; // verilator lint_off STMTDLY

    // To create a clock:
    // initial aclk = 0;
    // always #2 aclk = !aclk;

    // To dump data for visualization:
    // initial begin
    //     Default wavefile name with VCD format
    //     $dumpfile("vga_gen_testbench.vcd");
    //     Or use FST format with -fst argument
    //     $dumpfile("vga_gen_testbench.fst");
    //     Dump all the signals of the design
    //     $dumpvars(0, vga_gen_testbench);
    // end

    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        // setup() runs when a test begins
    end
    endtask

    task teardown(msg="");
    begin
        // teardown() runs when a test ends
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")

    //  Available macros:"
    //
    //    - `MSG("message"):       Print a raw white message
    //    - `INFO("message"):      Print a blue message with INFO: prefix
    //    - `SUCCESS("message"):   Print a green message if SUCCESS: prefix
    //    - `WARNING("message"):   Print an orange message with WARNING: prefix and increment warning counter
    //    - `CRITICAL("message"):  Print a purple message with CRITICAL: prefix and increment critical counter
    //    - `FAILURE("message"):   Print a red message with FAILURE: prefix and do **not** increment error counter
    //    - `ERROR("message"):     Print a red message with ERROR: prefix and increment error counter
    //
    //    - `FAIL_IF(aSignal):                 Increment error counter if evaluaton is true
    //    - `FAIL_IF_NOT(aSignal):             Increment error coutner if evaluation is false
    //    - `FAIL_IF_EQUAL(aSignal, 23):       Increment error counter if evaluation is equal
    //    - `FAIL_IF_NOT_EQUAL(aSignal, 45):   Increment error counter if evaluation is not equal
    //    - `ASSERT(aSignal):                  Increment error counter if evaluation is not true
    //    - `ASSERT(aSignal == 0):           Increment error counter if evaluation is not true
    //
    //  Available flag:
    //
    //    - `LAST_STATUS: tied to 1 if last macro did experience a failure, else tied to 0

    `UNIT_TEST("TESTCASE_NAME")

        // Describe here the testcase scenario
        //
        // Because SVUT uses long nested macros, it's possible
        // some local variable declaration leads to compilation issue.
        // You should declare your variables after the IOs declaration to avoid that.

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
