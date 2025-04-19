// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "tmds_gen.sv"
`include "tmds_encoder_dvi.sv"
`timescale 1 ns / 100 ps

module tb_tmds_gen();

    `SVUT_SETUP

    logic clk = 1;
    logic rst;
    logic [7:0] i_data;
    logic [1:0] i_control_data;
    logic i_blanking;
    logic [9:0] o_encoded;
    logic [9:0] s_encoded;

    tmds_gen 
    dut 
    (
    .i_clk          (clk),
    .i_rst          (rst),
    .i_data         (i_data),
    .i_control_data (i_control_data),
    .i_blanking     (i_blanking),
    .o_encoded      (o_encoded)
    );

    tmds_encoder_dvi inst_tmds_gen (
      .clk_pix(clk),
      .rst_pix(rst),
      .data_in(i_data),
      .ctrl_in(i_control_data), //only set one or all colors? idk...
      .de(~i_blanking),
      .tmds(s_encoded)
    );
    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask
    
    always #(5ns) clk= ~clk; // verilator lint_off STMTDLY

    // To dump data for visualization:
    initial begin
        // $dumpfile("wave.vcd");
        $dumpfile("wave.fst");
        $dumpvars(0, tb_tmds_gen);
    end

    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        rst = 1;
        i_data = '0;
        i_control_data = '0;
        i_blanking = '0;
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
    //    - `FAIL_IF(aSignal):                 Increment error counter if evaluaton is true
    //    - `FAIL_IF_NOT(aSignal):             Increment error coutner if evaluation is false
    //    - `FAIL_IF_EQUAL(aSignal, 23):       Increment error counter if evaluation is equal
    //    - `FAIL_IF_NOT_EQUAL(aSignal, 45):   Increment error counter if evaluation is not equal
    //    - `ASSERT(aSignal):                  Increment error counter if evaluation is not true
    //    - `ASSERT(aSignal == 0):           Increment error counter if evaluation is not true

    `UNIT_TEST("TESTCASE_NAME")
        #1;
        i_data = '1;
        repeat (30) begin
            wait_cycles(1);
            i_data = ~i_data;
        end
            i_data = 1;
        repeat (30) begin
            wait_cycles(1);
            i_data = {i_data[6:0],i_data[7]};
        end
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
