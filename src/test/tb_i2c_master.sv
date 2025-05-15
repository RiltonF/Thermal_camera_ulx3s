// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "i2c_master.sv"
`include "i2c_byte_gen.sv"
`include "i2c_bit_gen.sv"
`include "i2c_start_gen.sv"
`include "i2c_stop_gen.sv"
`include "i2c_req_manager.sv"
`timescale 1 ns / 100 ps

module tb_i2c_master();

    `SVUT_SETUP

    parameter int BURST_WIDTH = 4;
    parameter int CLK_FREQ = 25_000_000;
    parameter int I2C_FREQ = 100_0000;

    localparam int c_tansaction_time = CLK_FREQ / (4 * I2C_FREQ);
    logic clk=1;
    logic rst=1;
    logic i_enable;
    logic i_valid;
    logic i_we;
    logic i_sccb_mode;
    logic [6:0] i_addr_slave;
    logic [7:0] i_addr_reg;
    logic [BURST_WIDTH-1:0] i_burst_num;
    logic o_ready;
    logic       i_wr_fifo_valid;
    logic [7:0] i_wr_fifo_data;
    logic       o_wr_fifo_ready;
    logic       o_rd_fifo_valid;
    logic [7:0] o_rd_fifo_data;
    logic       i_rd_fifo_ready;

    logic s_set_sda = 1;
    logic s_set_scl = 1;
    wire sda, scl;
    pullup(sda);
    pullup(scl);
    assign sda = s_set_sda ? 1'bz : 1'b0;
    assign scl = s_set_scl ? 1'bz : 1'b0;

    i2c_master 
    #(
    .BURST_WIDTH (BURST_WIDTH),
    .CLK_FREQ    (CLK_FREQ),
    .I2C_FREQ    (I2C_FREQ)
    )
    dut 
    (
    .i_clk           (clk),
    .i_rst           (rst),
    .i_enable        (i_enable),
    .i_valid         (i_valid),
    .i_we            (i_we),
    .i_sccb_mode     (i_sccb_mode),
    .i_addr_slave    (i_addr_slave),
    .i_addr_reg      (i_addr_reg),
    .i_burst_num     (i_burst_num),
    .o_ready         (o_ready),
    .i_wr_fifo_valid (i_wr_fifo_valid),
    .i_wr_fifo_data  (i_wr_fifo_data),
    .o_wr_fifo_ready (o_wr_fifo_ready),
    .o_rd_fifo_valid (o_rd_fifo_valid),
    .o_rd_fifo_data  (o_rd_fifo_data),
    .i_rd_fifo_ready (i_rd_fifo_ready),
    .b_sda(sda),
    .b_scl(scl)
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
        $dumpvars(0, tb_i2c_master);
    end
    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        // setup() runs when a test begins
        rst = 1;
        i_enable = 0;
        i_valid = 0;
        i_we = 0;
        i_sccb_mode = 0;
        i_addr_slave = 0;
        i_addr_reg = 0;
        i_burst_num = 0;

        i_wr_fifo_valid = 0;
        i_wr_fifo_data = 0;
        i_rd_fifo_ready = 0;

        s_set_sda = 1;
        s_set_scl = 1;
        wait_cycles(8);
        rst = 0;
        i_rd_fifo_ready = 1;
    end
    endtask

    task teardown(msg="");
    begin
        rst = 1;
        s_set_sda = 1;
        s_set_scl = 1;
        wait_cycles(8);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")
    `UNIT_TEST("TESTCASE_NAME")
        #1ns;
        wait_cycles(4);
        i_enable = 1;
        i_we = 0;
        i_sccb_mode = 0;
        i_addr_slave = 'hff;
        i_addr_reg = 'h0f;
        i_burst_num = 0;
        i_wr_fifo_data = 'hcd;
        i_wr_fifo_valid = 1;
        i_rd_fifo_ready = 1;
        fork
            begin
                repeat (4) begin
                    i_valid = 1;
                    `WAIT(~o_ready);
                    wait_cycles(1);
                    // i_valid = 0;
                    i_we = ~i_we;
                    `WAIT(o_ready);
                    wait_cycles(1);
                end
                    i_valid = 0;
                    wait_cycles(8);
                    `WAIT(o_ready);
                    wait_cycles(40);
            end
            begin
                repeat (3*4) begin
                    `WAIT(
                        (dut.inst_i2c_byte_gen.s_r.bit_counter == 8) &
                        (dut.inst_i2c_bit_gen.i_req));
                    s_set_sda = ~dut.inst_i2c_bit_gen.i_we;
                    wait_cycles(c_tansaction_time*5);
                    s_set_sda = 1;
                    wait_cycles(1);
                end
            end
            begin
                repeat (2) begin
                    `WAIT(o_wr_fifo_ready);
                    wait_cycles(1);
                    i_wr_fifo_data = ~i_wr_fifo_data;
                    wait_cycles(1);
                end
                i_wr_fifo_valid = 0;
            end
        join

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
