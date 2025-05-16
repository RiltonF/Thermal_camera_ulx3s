// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "i2c_rom_cmd_parser.sv"
`include "ov7670_rom_sync.sv"
`include "rom_sync.sv"
`timescale 1 ns / 100 ps

module tb_i2c_rom_cmd_parser();

    `SVUT_SETUP

    parameter bit p_sccb_mode = 1'b1;
    parameter int p_slave_addr = 'h21;
    parameter bit p_wr_mode = 1'b1;
    parameter int p_rom_addr_width = 8;
    parameter int p_delay_const = 10;

    logic clk=1;
    logic rst=1;
    logic i_start;
    logic [15:0] i_data;
    logic [p_rom_addr_width-1:0] o_addr;
    logic o_done;
    logic o_cmd_valid;
    t_i2c_cmd o_cmd_data;
    logic [7:0] o_wr_data;
    logic i_cmd_ready;

    i2c_rom_cmd_parser 
    #(
    .p_sccb_mode      (p_sccb_mode),
    .p_slave_addr     (p_slave_addr),
    .p_wr_mode        (p_wr_mode),
    .p_rom_addr_width (p_rom_addr_width),
    .p_delay_const    (p_delay_const)
    )
    dut 
    (
    .i_clk       (clk),
    .i_rst       (rst),
    .i_start     (i_start),
    .i_data      (i_data),
    .o_addr      (o_addr),
    .o_done      (o_done),
    .o_cmd_valid (o_cmd_valid),
    .o_cmd_data  (o_cmd_data),
    .o_wr_data   (o_wr_data),
    .i_cmd_ready (i_cmd_ready)
    );

    ov7670_rom_sync inst_ov7670_config_rom (
        .clk(clk),
        .addr(o_addr),
        .data(i_data)
    );

    initial $timeformat(-9, 1, "ns", 8);
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
        $dumpfile("tb_i2c_rom_cmd_parser.fst");
        $dumpvars(0, tb_i2c_rom_cmd_parser);
    end


    task setup();
    begin
        // setup() runs when a test begins
        rst = 1;
        i_start = 0;
        i_cmd_ready = 0;
        wait_cycles(4);
        rst = 0;

    end
    endtask

    task teardown();
    begin
        // teardown() runs when a test ends
        rst = 1;
        wait_cycles(4);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")
    `UNIT_TEST("TESTCASE_NAME")
    #1ns;
    begin
        wait_cycles(4);
        i_start = 1;
        wait_cycles(4);
        i_cmd_ready = 1;
        i_start = 0;
        `WAIT(o_done)
        wait_cycles(4);
        i_start = 1;
        `WAIT(o_done)
        wait_cycles(4);
    end

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
