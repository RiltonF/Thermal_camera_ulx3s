// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "pixel_smoothing.sv"
`include "mu_ram_1r1w.v"
`timescale 1 ns / 100 ps

module tb_pixel_smoothing();

    `SVUT_SETUP

    parameter int MAX_ADDR = 2**6-1;
    localparam int ADDRW = $clog2(MAX_ADDR);
    logic [31:0] seed = 12;

    logic clk=1;
    logic rst=1;
    logic i_start;
    logic             i_wr_valid;
    logic [ADDRW-1:0] i_wr_addr;
    logic [    8-1:0] i_wr_data;
    logic             o_wr_valid;
    logic [ADDRW-1:0] o_wr_addr;
    logic [    8-1:0] o_wr_data;

    pixel_smoothing 
    #(
    .MAX_ADDR (MAX_ADDR)
    )
    dut 
    (
    .i_clk      (clk),
    .i_rst      (rst),
    .i_start    (i_start),
    .i_wr_valid (i_wr_valid),
    .i_wr_addr  (i_wr_addr),
    .i_wr_data  (i_wr_data),
    .o_wr_valid (o_wr_valid),
    .o_wr_addr  (o_wr_addr),
    .o_wr_data  (o_wr_data)
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
                wait_cycles(5000); \
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
        i_wr_valid = '0;
        i_wr_addr = '0;
        i_wr_data = '0;
        i_start = '0;
        // for(int x=0; x < $size(dut.inst_old_avg_mem.mem[x]); x++) 
        //     dut.inst_old_avg_mem.mem[x] = '0;
        wait_cycles(8);
        rst = 0;
    end
    endtask

    task teardown(msg="");
    begin
        rst = 1;
        wait_cycles(8);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")

    `UNIT_TEST("TESTCASE_NAME")
    #1ns;
    fork
    begin
        wait_cycles(8);
        while(1) begin
            i_wr_data = $random(seed);
            if(i_wr_addr >= MAX_ADDR) begin
                i_wr_valid = 0;
                wait_cycles(8);
                i_wr_valid = 1;
                i_wr_addr = '0;
                wait_cycles(1);
            end else begin
                i_wr_valid = 1;
                i_wr_addr++;
                wait_cycles(1);
            end
        end
    end

    begin
        wait_cycles(1000);
    end
    join_any
    disable fork;

    `UNIT_TEST_END

    `UNIT_TEST("TESTCASE_NAME")
    #1ns;
    fork
    begin
        wait_cycles(8);
        while(1) begin
            // i_wr_data = ~i_wr_addr;
            if(i_wr_addr >= MAX_ADDR) begin
                i_wr_valid = 0;
                wait_cycles(8);
                i_wr_valid = 1;
                i_wr_addr = '0;
                i_wr_data = i_wr_addr;
                wait_cycles(1);
            end else begin
                i_wr_valid = 1;
                i_wr_addr++;
                i_wr_data = i_wr_addr;
                wait_cycles(1);
            end
        end
    end

    begin
        wait_cycles(1000);
    end
    join_any
    disable fork;

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
