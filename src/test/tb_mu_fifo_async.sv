// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "mu_fifo_async.v"
`include "mu_drsync.v"
`timescale 1 ns / 100 ps

module tb_mu_fifo_async();

    `SVUT_SETUP

    parameter DW = 32;
    parameter DEPTH = 4;
    parameter THRESH_FULL = DEPTH - 1;
    parameter THRESH_EMPTY = 1;

    logic rst=1;
    logic              wr_clk=1;
    logic              wr_nreset;
    logic  [DW-1:0]    wr_din;
    logic              wr_valid;
    logic              wr_ready;
    logic              wr_almost_full;

    logic              rd_clk=1;
    logic              rd_nreset;
    logic  [DW-1:0]    rd_dout;
    logic              rd_ready;
    logic              rd_valid;
    logic              rd_almost_empty;

    mu_fifo_async 
    #(
    .DW           (DW),
    .DEPTH        (DEPTH),
    .THRESH_FULL  (THRESH_FULL),
    .THRESH_EMPTY (THRESH_EMPTY)
    )
    dut 
    (
    .wr_clk          (wr_clk),
    .wr_nreset       (~rst),
    .wr_din          (wr_din),
    .wr_valid        (wr_valid),
    .wr_ready        (wr_ready),
    .wr_almost_full  (wr_almost_full),
    .rd_clk          (rd_clk),
    .rd_nreset       (~rst),
    .rd_dout         (rd_dout),
    .rd_ready        (rd_ready),
    .rd_valid        (rd_valid),
    .rd_almost_empty (rd_almost_empty)
    );
    
    task automatic wait_wr_cycles(input int n);
        repeat (n) @(posedge wr_clk);
    endtask
    task automatic wait_rd_cycles(input int n);
        repeat (n) @(posedge rd_clk);
    endtask

    //Clocks
    always #(10ns) wr_clk= ~wr_clk; // verilator lint_off STMTDLY
    always #(5ns) rd_clk= ~rd_clk; // verilator lint_off STMTDLY

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
        wr_din = '0;
        wr_valid = '0;
        rd_ready = '0;
        wait_wr_cycles(8);
        rst = 0;
    end
    endtask

    task teardown(msg="");
    begin
        rst = 1;
        wait_wr_cycles(8);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")
    `UNIT_TEST("TESTCASE_NAME")
    #1ns;
    begin
        wait_wr_cycles(10);
        for (int i = 0; i < 4; i++) begin
            wr_din = i;
            wr_valid = 1;
            wait_wr_cycles(1);
        end
        wait_wr_cycles(10);
    end

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
