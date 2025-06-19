// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "sdram_top.sv"
`timescale 1 ns / 100 ps

module tb_sdram_top();

    `SVUT_SETUP

    parameter int p_sdram_dataw = 16;
    parameter int p_sdram_rows = 8192;
    parameter int p_sdram_banks= 4;
    localparam int c_addrw = $clog2(p_sdram_rows);
    localparam int c_bankw = $clog2(p_sdram_banks);

    logic                     i_clk_wr_fifo;
    logic                     i_wr_fifo_valid;
    logic [p_sdram_dataw-1:0] i_wr_fifo_data;
    logic                     o_wr_fifo_ready;
    logic                     o_rd_fifo_valid;
    logic [p_sdram_dataw-1:0] o_rd_fifo_data;
    logic                     i_rd_fifo_ready;
    logic                     o_sdram_clk;
    logic                     o_sdram_cke;
    logic                     o_sdram_cs_n;
    logic                     o_sdram_we_n;
    logic                     o_sdram_ras_n;
    logic                     o_sdram_cas_n;
    logic [      c_addrw-1:0] o_sdram_addr;
    logic [      c_bankw-1:0] o_sdram_ba;
    logic [              1:0] o_sdram_dqm;
    logic [              1:0] i_debug_trig;
    logic [              7:0] o_debug_status;

    logic wr_clk=1;
    logic rd_clk=1;
    logic rst=1;

    sdram_top 
    #(
    .p_sdram_dataw (p_sdram_dataw),
    .p_sdram_rows  (p_sdram_rows),
    .p_sdram_banks (p_sdram_banks)
    )
    dut 
    (
    .i_clk           (wr_clk),
    .i_rst           (rst),
    .i_clk_wr_fifo   (wr_clk),
    .i_wr_fifo_valid (i_wr_fifo_valid),
    .i_wr_fifo_data  (i_wr_fifo_data),
    .o_wr_fifo_ready (o_wr_fifo_ready),
    .o_rd_fifo_valid (o_rd_fifo_valid),
    .o_rd_fifo_data  (o_rd_fifo_data),
    .i_rd_fifo_ready (i_rd_fifo_ready),
    .o_sdram_clk     (o_sdram_clk),
    .o_sdram_cke     (o_sdram_cke),
    .o_sdram_cs_n    (o_sdram_cs_n),
    .o_sdram_we_n    (o_sdram_we_n),
    .o_sdram_ras_n   (o_sdram_ras_n),
    .o_sdram_cas_n   (o_sdram_cas_n),
    .o_sdram_addr    (o_sdram_addr),
    .o_sdram_ba      (o_sdram_ba),
    .o_sdram_dqm     (o_sdram_dqm),
    .i_debug_trig    (i_debug_trig),
    .o_debug_status  (o_debug_status)
    );

    assign dut.s_sdram_clk = wr_clk;
    assign dut.s_sdram_rst = rst;

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
        rst=1;
        i_debug_trig = '0;
        dut.s_sdram_ready = '0;
        wait_wr_cycles(4);
        rst=0;
    begin
    end
    endtask

    task teardown(msg="");
    begin
        rst=1;
        wait_wr_cycles(4);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")
    `UNIT_TEST("TESTCASE_NAME")

    #1ns;
// begin repeat (4) begin
//         wait_wr_cycles(4);
//         dut.s_sdram_ready = 1;
//         wait_wr_cycles(4);
//         i_debug_trig = 'b10;
//         wait_wr_cycles(2);
//         i_debug_trig = ~i_debug_trig;
//         dut.s_sdram_ready = 0;
//         wait_wr_cycles(8);
//         dut.s_sdram_ready = 1;
//     end
//     end
        force dut.s_r.read_row = 'd598;
        force dut.s_r.write_row = 'd598;
        wait_wr_cycles(4);
        release dut.s_r.read_row;
        release dut.s_r.write_row;
begin repeat (4) begin
        wait_wr_cycles(4);
        dut.s_sdram_ready = 1;
        wait_wr_cycles(4);
        i_debug_trig[0] = 1;
        wait_wr_cycles(2);
        i_debug_trig[0] = 0;
        dut.s_sdram_ready = 0;
        wait_wr_cycles(8);
        dut.s_sdram_ready = 1;
    end
    end
begin repeat (4) begin
        wait_wr_cycles(4);
        dut.s_sdram_ready = 1;
        wait_wr_cycles(4);
        i_debug_trig[1] = 1;
        wait_wr_cycles(2);
        i_debug_trig[1] = 0;
        dut.s_sdram_ready = 0;
        wait_wr_cycles(8);
        dut.s_sdram_ready = 1;
    end
        wait_wr_cycles(8);
    end

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
