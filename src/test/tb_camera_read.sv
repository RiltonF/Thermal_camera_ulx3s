// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "camera_read.sv"
`timescale 1 ns / 100 ps

module tb_camera_read();

    `SVUT_SETUP

    logic clk=1;
    logic rst=1;
    logic i_vsync;
    logic i_href;
    logic [7:0] i_data;
    logic o_valid;
    logic [15:0] o_data;
    logic o_frame_done;
    logic [9:0] o_row;
    logic [9:0] o_col;

    camera_read 
    dut 
    (
    .i_clk        (clk),
    .i_rst        (rst),
    .i_vsync      (i_vsync),
    .i_href       (i_href),
    .i_data       (i_data),
    .o_valid      (o_valid),
    .o_data       (o_data),
    .o_frame_done (o_frame_done),
    .o_row        (o_row),
    .o_col        (o_col)
    );


    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    //Clocks
    always #(5ns) clk= ~clk; // verilator lint_off STMTDLY

    // To dump data for visualization:
    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, tb_camera_read);
    end

    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        rst = 1;
        i_data = '0;
        i_href = '0;
        i_vsync = '0;
        wait_cycles(4);
        rst = 0;
    end
    endtask

    // teardown() runs when a test ends
    task teardown(msg="");
    begin
        wait_cycles(4);
        rst = 1;
        i_data = '0;
        wait_cycles(4);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")

    `UNIT_TEST("TESTCASE_NAME")
    #1;
    fork
        wait_cycles(4);
        i_data = '0;
        begin
            repeat (4) begin
            wait_cycles(4);
            i_vsync = 1;
            wait_cycles(4);
            i_href = 1;
            wait_cycles(10);
            i_href = 0;
            wait_cycles(4);
            i_vsync = 0;
            end
        end
        begin
            repeat(40) begin
                i_data = i_data+1;
                wait_cycles(1);
            end
        end
    join


    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
