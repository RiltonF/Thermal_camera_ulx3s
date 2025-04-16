// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "serializer.sv"
`timescale 1 ns / 100 ps

module tb_serializer();

    `SVUT_SETUP

    parameter p_data_width = 10;

    logic clk_data = 1, clk_sdr = 1, clk_ddr = 1, rst = 1;
    logic [p_data_width-1:0] i_data;
    logic [1:0] o_data_ddr, o_data_sdr;
    logic [1:0] o_clk_ddr, o_clk_sdr;

    serializer #(
        .p_data_width (p_data_width),
        .p_ddr_mode   (1)
    ) dut_ddr (
        .i_clk_data  (clk_data),
        .i_clk_shift (clk_ddr),
        .i_rst       (rst),
        .i_data      (i_data),
        .o_data      (o_data_ddr),
        .o_clk       (o_clk_ddr)
    );

    serializer #(
        .p_data_width (p_data_width),
        .p_ddr_mode   (0)
    ) dut_sdr (
        .i_clk_data  (clk_data),
        .i_clk_shift (clk_sdr),
        .i_rst       (rst),
        .i_data      (i_data),
        .o_data      (o_data_sdr),
        .o_clk       (o_clk_sdr)
    );
    task automatic wait_cycles_data(input int n);
        repeat (n) @(posedge clk_data);
    endtask
    task automatic wait_cycles_ddr(input int n);
        repeat (n) @(posedge clk_ddr);
    endtask
    task automatic wait_cycles_sdr(input int n);
        repeat (n) @(posedge clk_sdr);
    endtask

    //Clocks
    always #(5ns) clk_sdr = ~clk_sdr; // verilator lint_off STMTDLY
    always #(10ns) clk_ddr = ~clk_ddr; // verilator lint_off STMTDLY
    always #(50ns) clk_data = ~clk_data; // verilator lint_off STMTDLY

    // To dump data for visualization:
    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, tb_serializer);
    end

    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        rst = 1
        i_data = '0;
        wait_cycles_data(4);
        rst = 0;
    end
    endtask

    // teardown() runs when a test ends
    task teardown(msg="");
    begin
        wait_cycles_data(4);
        rst = 1;
        i_data = '0;
        wait_cycles_data(4);
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
    //
    `UNIT_TEST("sdr_data shift_check multiple")
        #1;
        begin
            fork
            begin
                i_data = 'b1101010101;
                repeat(5) begin
                    wait_cycles_data(1);
                    i_data = ~i_data;
                end
            end
            begin
                wait(dut_sdr.s_shift_clock_in_sync);
                wait_cycles_data(1);
                repeat(5) begin
                    for(int j = 0; j < 10; j++) begin
                        #1;
                        // $display("%b != %b",o_data_sdr[0], i_data[j]);
                        `FAIL_IF_NOT_EQUAL(o_data_sdr[0], i_data[j])
                        wait_cycles_sdr(1);
                    end
                end
            end
            join
        end
    `UNIT_TEST_END
    `UNIT_TEST("ddr_data shift_check multiple")
        #1;
        begin
            fork
            begin
                i_data = 'b1101010101;
                repeat(5) begin
                    wait_cycles_data(1);
                    i_data = ~i_data;
                end
            end
            begin
                wait(dut_ddr.s_shift_clock_in_sync);
                wait_cycles_data(1);
                repeat(5) begin
                    for(int i = 0; i < 5; i++) begin
                        #1;
                        // $info("%d",i);
                        // $display("%b != %b",o_data_ddr, i_data[i*2+:2]);
                        `FAIL_IF_NOT_EQUAL(o_data_ddr, i_data[i*2+:2])
                        wait_cycles_ddr(1);
                    end
                end
            end
            join
        end
    `UNIT_TEST_END
    `UNIT_TEST("sdr_data shift_check")
        #1;
        begin
            wait_cycles_data(1);
            i_data = 'b000001;
            wait_cycles_data(1);
            wait(dut_sdr.s_shift_clock_in_sync);
            wait_cycles_data(1);
            for(int j = 0; j < 10; j++) begin
                #1;
                // $display("%b != %b",o_data_sdr[0], i_data[j]);
                `FAIL_IF_NOT_EQUAL(o_data_sdr[0], i_data[j])
                wait_cycles_sdr(1);
            end
        end
    `UNIT_TEST_END
    `UNIT_TEST("ddr_data shift_check")
        #1;
        begin
            wait_cycles_data(1);
            i_data = 'b0000011111;
            wait_cycles_data(1);
            wait(dut_ddr.s_shift_clock_in_sync);
            wait_cycles_data(1);
            for(int i = 0; i < 5; i++) begin
                #1;
                // $info("%d",i);
                // $display("%b != %b",o_data_ddr, i_data[i*2+:2]);
                `FAIL_IF_NOT_EQUAL(o_data_ddr, i_data[i*2+:2])
                wait_cycles_ddr(1);
            end
        end
    `UNIT_TEST_END

    // `UNIT_TEST("ddr_data shift_check")
    //     #10;
    //     fork
    //     begin
    //         wait_cycles_data(1);
    //         i_data = 'b0000011111;
    //         repeat(10) begin
    //             wait_cycles_data(1);
    //             // i_data = ~i_data;
    //         end
    //         i_data = '0;
    //     end
    //     begin
    //         // i_data = 'b1111000011;
    //         wait_cycles_ddr(3);
    //         // i_data = '1;
    //         wait_cycles_ddr(2);
    //         // i_data = 'b1000100001;
    //         wait_cycles_ddr(10);
    //         wait_cycles_ddr(100);
    //     end
    //     join
    // `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
