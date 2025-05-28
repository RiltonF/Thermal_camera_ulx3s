// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "mlx90640_top.sv"
`include "mlx90640_controller.sv"
`include "i2c_master.sv"
`include "i2c_master_wrapper_16b.sv"
`include "i2c_byte_gen.sv"
`include "i2c_bit_gen.sv"
`include "i2c_start_gen.sv"
`include "i2c_stop_gen.sv"
`include "i2c_req_manager_16bit.sv"
`include "mu_fifo_sync.v"
`include "mu_widthadapt_1_to_2.v"
// `include "mu_ram_1r1w.v"

`timescale 1 ns / 100 ps

module tb_mlx90640_top();

    `SVUT_SETUP

    parameter int p_slave_addr = 'h33;
    parameter int p_delay_const = 4;

    logic clk=1;
    logic rst=1;
    logic [1:0] i_trig;
    logic [7:0] o_debug;
    logic s_set_sda = 1;
    logic s_set_scl = 1;
    wire sda, scl;
    pullup(sda);
    pullup(scl);
    assign sda = s_set_sda ? 1'bz : 1'b0;
    assign scl = s_set_scl ? 1'bz : 1'b0;

    logic s_sda;
    assign s_sda = sda;
    logic s_scl;
    assign s_scl = scl;

    mlx90640_top 
    #(
    .p_slave_addr  (p_slave_addr),
    .p_delay_const (p_delay_const)
    )
    dut 
    (
    .i_clk   (clk),
    .i_rst   (rst),
    .i_trig  (i_trig),
    .o_debug (o_debug),
    .b_sda(sda),
    .b_scl(scl)
    );

    defparam dut.inst_i2c_master_mlx.I2C_FREQ = 1000000;


    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    `define WAIT(condition) \
        fork \
            begin \
                wait(condition); \
            end \
            begin \
                wait_cycles(8000); \
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
        $dumpvars(0, tb_mlx90640_top);
    end

    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        rst=1;
        i_trig = 0;
        wait_cycles(8);
        rst=0;

        // setup() runs when a test begins
    end
    endtask

    task teardown(msg="");
    begin
        rst=1;
        wait_cycles(8);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")

    `UNIT_TEST("TESTCASE_NAME")
    #1ns;
    fork
    static logic [7:0] c_val = 8'b10000;
    begin
        while (1) begin
            `WAIT(dut.inst_i2c_master_mlx.inst_i2c_master.inst_i2c_byte_gen.i_req & ~dut.inst_i2c_master_mlx.inst_i2c_master.inst_i2c_byte_gen.i_we)
            wait_cycles(4);
            for(int i = 0; i<8;i++) begin
                `WAIT(~s_scl)
                wait_cycles(10);
                s_set_sda = c_val[i]; 
                `WAIT(s_scl)
            end
            `WAIT(~s_scl)
            wait_cycles(4);
            s_set_sda = 1; 
        end
    end
    begin
        while (1) begin
            `WAIT(dut.inst_i2c_master_mlx.inst_i2c_master.inst_i2c_byte_gen.i_req & dut.inst_i2c_master_mlx.inst_i2c_master.inst_i2c_byte_gen.i_we)
            `WAIT(dut.inst_i2c_master_mlx.inst_i2c_master.inst_i2c_byte_gen.s_r.bit_counter == 8)
            s_set_sda = 0; 
            `WAIT(s_scl)
            `WAIT(~s_scl)
            wait_cycles(4);
            s_set_sda = 1; 
        end
    end
    begin
        i_trig = 1;
        repeat (8) begin
            `WAIT(dut.s_cmd_valid & dut.s_cmd_ready)
            wait_cycles(4);
        end
        // wait_cycles(8000);
    end
    join_any
    disable fork;

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
