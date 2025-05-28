// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "mlx90640_controller.sv"
`timescale 1 ns / 100 ps

module tb_mlx90640_controller();

    `SVUT_SETUP

    parameter bit p_sccb_mode = 1'b0;
    parameter int p_slave_addr = 6'h33;
    parameter int p_delay_const = 10;

    logic clk=1;
    logic rst=1;
    logic i_start;
    logic o_done;
    logic o_cmd_valid;
    t_i2c_cmd_16b o_cmd_data;
    logic i_cmd_ready;
    logic i_cmd_ack;
    logic        o_wr_fifo_valid;
    logic [15:0] o_wr_fifo_data;
    logic        i_wr_fifo_ready;
    logic       i_rd_fifo_valid;
    logic [7:0] i_rd_fifo_data;
    logic       o_rd_fifo_ready;

    mlx90640_controller 
    #(
    .p_sccb_mode   (p_sccb_mode),
    .p_slave_addr  (p_slave_addr),
    .p_delay_const (p_delay_const)
    )
    dut 
    (
    .i_clk           (clk),
    .i_rst           (rst),
    .i_start         (i_start),
    .o_done          (o_done),
    .o_cmd_valid     (o_cmd_valid),
    .o_cmd_data      (o_cmd_data),
    .i_cmd_ready     (i_cmd_ready),
    .i_cmd_ack       (i_cmd_ack),
    .o_wr_fifo_valid (o_wr_fifo_valid),
    .o_wr_fifo_data  (o_wr_fifo_data),
    .i_wr_fifo_ready (i_wr_fifo_ready),
    .i_rd_fifo_valid (i_rd_fifo_valid),
    .i_rd_fifo_data  (i_rd_fifo_data),
    .o_rd_fifo_ready (o_rd_fifo_ready)
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
        $dumpvars(0, tb_mlx90640_controller);
    end


    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        rst=1;
        i_start = 0;
        i_cmd_ready = 0;
        i_cmd_ack = 0;
        i_wr_fifo_ready = 0;
        i_rd_fifo_valid = 0;
        i_rd_fifo_data = '0;
        wait_cycles(8);
        rst=0;
        
    end
    endtask

    task teardown(msg="");
    begin
        rst=1;
        wait_cycles(16);
        rst=0;
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")

    `UNIT_TEST("TESTCASE_NAME")
    #1ns;
    fork
    begin
        while(1) begin
            i_cmd_ready = 1;
            `WAIT(o_cmd_valid)
            wait_cycles(1);
            i_cmd_ready = 0;
            wait_cycles(4);
        end
    end
    begin
        i_rd_fifo_data = 'b1000;
        while(1) begin
            `WAIT(o_cmd_valid)
            wait_cycles(2);
            i_rd_fifo_valid = 1;
            `WAIT(o_rd_fifo_ready)
            wait_cycles(1);
            i_rd_fifo_data = ~i_rd_fifo_data;
            i_rd_fifo_valid = 0;
        end
    end
    begin
        wait_cycles(4);
        i_wr_fifo_ready = 1;
        i_cmd_ack = 1;
        wait_cycles(4);
        i_start = 1;
        `WAIT(o_cmd_valid)
        i_start = 0;
        wait_cycles(200);
        i_cmd_ack = 0;
        wait_cycles(200);
    end
    join_any
    disable fork;

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
