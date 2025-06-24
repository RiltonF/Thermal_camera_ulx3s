// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "sdram_top_new.sv"
`include "xd.sv"
`include "mu_fifo_async.v"
`include "mu_drsync.v"
`include "simple_widthadapt_1_to_x.sv"
`timescale 1 ns / 100 ps

module tb_sdram_top_new();

    `SVUT_SETUP

    parameter p_clock_feq = 100_000_000;
    parameter int p_dram_burst_size = 8;
    parameter int p_dram_dataw = 16;
    parameter int p_dram_rows = 8192;
    parameter int p_dram_cols = 512;
    parameter int p_dram_banks= 4;
    localparam int c_addrw = $clog2(p_dram_rows);
    localparam int c_bankw = $clog2(p_dram_banks);
    localparam int c_roww = $clog2(p_dram_rows);
    localparam int c_colw = $clog2(p_dram_rows);
    localparam int c_req_addrw = c_bankw + c_colw + c_roww;

    logic                     clk=1;
    logic                     rst=1;
    logic                     i_clk_wr_fifo;
    logic                     i_wr_fifo_valid;
    logic [ p_dram_dataw+1:0] i_wr_fifo_data;
    logic                     o_wr_fifo_ready;
    logic                     i_clk_rd_fifo;
    logic                     o_rd_fifo_valid;
    logic [ p_dram_dataw-1:0] o_rd_fifo_data;
    logic                     i_rd_fifo_ready;
    logic                     i_new_frame;
    logic                     i_new_line;
    logic [      c_addrw-1:0] o_dram_addr   /* Read/Write Address */;
    logic [      c_bankw-1:0] o_dram_ba     /* Bank Address */;
    logic                     o_dram_ldqm   /* Low byte data mask */;
    logic                     o_dram_udqm   /* High byte data mask */;
    logic                     o_dram_we_n   /* Write enable */;
    logic                     o_dram_cas_n  /* Column address strobe */;
    logic                     o_dram_ras_n  /* Row address strobe */;
    logic                     o_dram_cs_n   /* Chip select */;
    logic                     o_dram_clk    /* DRAM Clock */;
    logic                     o_dram_cke    /* Clock Enable */;
    logic                     o_dram_initialized;
    logic [              1:0] i_debug_trig;
    logic [              7:0] o_debug_status;

    sdram_top_new 
    #(
    .p_clock_feq       (p_clock_feq),
    .p_dram_burst_size (p_dram_burst_size),
    .p_dram_dataw      (p_dram_dataw),
    .p_dram_rows       (p_dram_rows),
    .p_dram_cols       (p_dram_cols),
    .p_dram_banks      (p_dram_banks)
    )
    dut 
    (
    .i_dram_clk         (clk),
    .i_rst              (rst),
    .i_clk_wr_fifo      (clk),
    .i_wr_fifo_valid    (i_wr_fifo_valid),
    .i_wr_fifo_data     (i_wr_fifo_data),
    .o_wr_fifo_ready    (o_wr_fifo_ready),
    .i_clk_rd_fifo      (clk),
    .o_rd_fifo_valid    (o_rd_fifo_valid),
    .o_rd_fifo_data     (o_rd_fifo_data),
    .i_rd_fifo_ready    (i_rd_fifo_ready),
    .i_new_frame        (i_new_frame),
    .i_new_line         (i_new_line),
    .o_dram_initialized (o_dram_initialized),
    .i_debug_trig       (i_debug_trig),
    .o_debug_status     (o_debug_status)
    );

    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

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
        rst=1;
        i_new_frame=0;
        i_new_line=0;
        i_wr_fifo_data='0;
        i_wr_fifo_valid='0;
        dut.s_load_rd_req_ready = 0;
        wait_cycles(4);
        rst=0;
        // setup() runs when a test begins
    end
    endtask

    task teardown(msg="");
    begin
        rst=1;
        wait_cycles(4);
        // teardown() runs when a test ends
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")
    `UNIT_TEST("wr_req")
    #1ns;
    fork
    begin
        repeat (2) begin
        wait_cycles(4);
        i_wr_fifo_valid=1; 
        i_wr_fifo_data = {16'hbeef,2'b11};
        wait_cycles(8);
        i_wr_fifo_data = {16'hbeef,2'b00};
        wait_cycles(8*84);
        i_wr_fifo_valid=0; 
        wait_cycles(4);
        i_wr_fifo_valid=1; 
        wait_cycles(8*2);
        wait_cycles(4);
    end
    end
    begin
        repeat (2) begin
        dut.s_wr_req_ready = 0;
        repeat (84) begin
            wait(dut.s_wr_req_valid);
            wait_cycles(4);
            dut.s_wr_req_ready = 1;
            wait_cycles(1);
            dut.s_wr_req_ready = 0;
            wait_cycles(1);
        end
        end
    end
    join

    `UNIT_TEST_END
    `UNIT_TEST("Test read req")
    #1ns;
    begin
        wait_cycles(4);
        dut.s_load_rd_req_ready = 1;
        wait_cycles(4);
        i_new_frame=1;
        wait_cycles(1);
        i_new_frame=0;
        wait_cycles(4);
        repeat(480) begin
            wait(~dut.s_load_rd_req_valid);
            wait_cycles(4);
            i_new_line=1;
            wait_cycles(1);
            i_new_line=0;
            wait_cycles(6);
        end
        wait_cycles(150);
    end

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
