// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "simple_widthadapt_1_to_x.sv"
`timescale 1 ns / 100 ps

module tb_simple_widthadapt_1_to_x();

    `SVUT_SETUP

    parameter int p_iwidth = 16;
    parameter int p_x = 8;

    localparam int p_owidth = p_iwidth * p_x;
    localparam int p_xw = $clog2(p_x);

    logic clk=1;
    logic rst=1;
    logic                i_valid;
    logic [p_iwidth-1:0] i_data;
    logic                o_ready;
    logic                o_valid;
    logic [p_owidth-1:0] o_data;
    logic [p_iwidth-1:0] o_data_array [p_x];
    logic                i_ready;

    simple_widthadapt_1_to_x 
    #(
    .p_iwidth (p_iwidth),
    .p_x      (p_x)
    )
    dut 
    (
    .i_clk   (clk),
    .i_rst   (rst),
    .i_valid (i_valid),
    .i_data  (i_data),
    .o_ready (o_ready),
    .o_valid (o_valid),
    .o_data  (o_data),
    .i_ready (i_ready)
    );

    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    `define WAIT(condition) \
        fork \
            begin \
                wait(condition); \
            end \
            begin \
                wait_cycles(8000); \
                `ERROR($sformatf("Timed out waiting for condition: '%s' at time %0t", condition, $time)) \
                $finish; \
            end \
        join_any \
        disable fork; \

    //Clocks
    always #(5ns) clk= ~clk; // verilator lint_off STMTDLY

    // To dump data for visualization:
    initial begin
        $dumpfile("wave.fst");
        $dumpvars;
    end

    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        rst = 1;
        i_valid = '0;
        i_data = '0;
        i_ready = '0;
        wait_cycles(4);
        rst = 0;
        wait_cycles(1);
    end
    endtask

    task teardown(msg="");
    begin
        rst = 1;
        wait_cycles(4);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")
    `UNIT_TEST("TESTCASE_NAME")
    #1ns;
    begin
    fork
    begin
        logic [3:0] v_count = 0;
        forever begin
            i_valid = 1;
            i_data = {p_iwidth/$bits(v_count){v_count}};
            wait_cycles(1);
            if(o_ready)v_count++;
        end
    end
    begin
        repeat(4) begin
            `WAIT(o_valid)
            $display($time);
            wait_cycles(1);
            i_ready = 1;
            wait_cycles(1);
            i_ready = 0;
            wait_cycles(1);
        end
        i_ready = 1;
        wait_cycles(40);
    end
    join_any
    disable fork;
    end
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
