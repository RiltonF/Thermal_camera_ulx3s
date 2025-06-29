// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "flat_field_correction.sv"
`include "mu_ram_1r1w.v"
`timescale 1 ns / 100 ps

module tb_flat_field_correction();

    `SVUT_SETUP

    parameter int DATAW = 16;
    parameter int MAX_ADDR = 32*24-1;
    parameter int SAMPLE_FRAMES = 1;
    localparam int ADDRW = $clog2(MAX_ADDR);

    logic clk=1;
    logic rst=1;
    logic i_start;
    logic             i_wr_valid;
    logic [ADDRW-1:0] i_wr_addr;
    logic [DATAW-1:0] i_wr_data;
    logic             i_rd_valid;
    logic [ADDRW-1:0] i_rd_addr;
    logic [DATAW-1:0] o_rd_data;
    logic signed [DATAW-1:0] o_frame_avg;
    logic i_subpage_num;

    flat_field_correction 
    #(
    .DATAW         (DATAW),
    .MAX_ADDR      (MAX_ADDR),
    .SAMPLE_FRAMES (SAMPLE_FRAMES)
    )
    dut 
    (
    .i_clk       (clk),
    .i_rst       (rst),
    .i_start     (i_start),
    .i_wr_valid  (i_wr_valid),
    .i_wr_addr   (i_wr_addr),
    .i_wr_data   (i_wr_data),
    .i_rd_valid  (i_rd_valid),
    .i_rd_addr   (i_rd_addr),
    .o_rd_data   (o_rd_data),
    .i_subpage_num,
    .o_frame_avg (o_frame_avg)
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
        rst = 1;
        i_wr_valid = 0;
        i_wr_addr = 0;
        i_wr_data = 0;
        i_rd_valid = 0;
        i_rd_addr = 0;
        i_start = 0;
        i_subpage_num = 0;
        wait_cycles(4);
        rst = 0;
    end
    endtask

    task teardown(msg="");
    begin
        rst = 1;
        wait_cycles(4);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")
    `UNIT_TEST("frame loading")
    #1ns;
    fork
    begin
        wait_cycles(4);
        forever begin
            i_wr_valid = 1;
            wait_cycles(1);
            i_wr_valid = 0;
            i_wr_addr++;
            i_wr_data++;
            wait_cycles(4);
            if (i_wr_addr >= MAX_ADDR+1) begin
                i_wr_valid = 0;
                i_wr_addr = 0;
                i_wr_data = 0;
                wait_cycles(4);
                i_subpage_num = ~i_subpage_num;
            end
        end
    end
    begin
        wait_cycles(4);
        forever begin
            i_rd_valid = 1;
            wait_cycles(1);
            i_rd_addr++;
            if (i_rd_addr >= MAX_ADDR+64) begin
                i_rd_valid = 0;
                i_rd_addr = 0;
                wait_cycles(4);
            end
        end
    end
    begin
        wait_cycles(8);
        i_start = 1;
        wait_cycles(1);
        i_start = 0;
        wait(dut.s_r.frame_count == 1);
        wait_cycles(4);
        `ASSERT(o_frame_avg == (MAX_ADDR*(MAX_ADDR+1)/2*85)>>16)
        wait(i_rd_addr == 0 & i_rd_valid);
        wait_cycles(1);
        for (int i = 0; i <= MAX_ADDR; i++)begin
            #1ns;
            `ASSERT(o_rd_data == i)
            wait_cycles(1);
        end
    end
    join_any
    disable fork;


    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
