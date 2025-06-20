// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "i2c_start_gen.sv"
`timescale 1 ns / 100 ps

module tb_i2c_start_gen();

    `SVUT_SETUP

    parameter int CLK_FREQ = 25_000_000;
    parameter int I2C_FREQ = 100_0000;

    logic clk=1;
    logic rst=1;
    logic i_req;
    logic o_done;
    logic o_ready;
    logic o_sda_drive;
    logic o_scl_drive;
    wire sda, scl;

    logic s_set_sda = 1;
    logic s_set_scl = 1;

    pullup(sda);
    pullup(scl);

    assign sda = s_set_sda ? 1'bz : 1'b0;
    assign scl = s_set_scl ? 1'bz : 1'b0;

    assign sda = o_sda_drive ? 1'bz : 1'b0;
    assign scl = o_scl_drive ? 1'bz : 1'b0;

    i2c_start_gen 
    #(
    .CLK_FREQ (CLK_FREQ),
    .I2C_FREQ (I2C_FREQ)
    )
    dut 
    (
    .i_clk       (clk),
    .i_rst       (rst),
    .i_req       (i_req),
    .i_enable    (1'b1), //this will be tested later in the arbitration phase
    .o_done      (o_done),
    .o_ready     (o_ready),
    .i_sda       (sda),
    .i_scl       (scl),
    .o_sda_drive (o_sda_drive),
    .o_scl_drive (o_scl_drive)
    );

    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    //Clocks
    always #(5ns) clk= ~clk; // verilator lint_off STMTDLY

    // To dump data for visualization:
    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, tb_i2c_start_gen);
    end
    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        rst = 1;
        s_set_sda = 1;
        s_set_scl = 1;
        i_req = 0;
        wait_cycles(4);
        rst = 0;
    end
    endtask

    task teardown(msg="");
    begin
        wait_cycles(4);
        rst = 1;
        i_req = 0;
        s_set_sda = 1;
        s_set_scl = 1;
        wait_cycles(4);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")

    `UNIT_TEST("Start_scl_low_sda_high")
    #1ns;
    begin
        wait_cycles(4);
        s_set_sda = 1;
        s_set_scl = 0;
        wait_cycles(1);
        i_req = 1;
        wait(~o_ready);
        s_set_sda = 1;
        s_set_scl = 1;
        wait(o_done);
        wait_cycles(1);
        `ASSERT(sda == 0)
        `ASSERT(scl == 0)
        i_req = 0;
        wait_cycles(4);
        `ASSERT(sda == 0)
        `ASSERT(scl == 0)
        wait_cycles(4);
    end
    `UNIT_TEST_END
    `UNIT_TEST("Start_scl_low_sda_low")
    #1ns;
    begin
        wait_cycles(4);
        s_set_sda = 0;
        s_set_scl = 0;
        wait_cycles(1);
        i_req = 1;
        wait(~o_ready);
        s_set_sda = 1;
        s_set_scl = 1;
        wait(o_done);
        wait_cycles(1);
        `ASSERT(sda == 0)
        `ASSERT(scl == 0)
        i_req = 0;
        wait_cycles(4);
        `ASSERT(sda == 0)
        `ASSERT(scl == 0)
        wait_cycles(4);
    end
    `UNIT_TEST_END
    `UNIT_TEST("Start_scl_high")
    #1ns;
    begin
        wait_cycles(4);
        s_set_sda = 1;
        s_set_scl = 1;
        wait_cycles(1);
        i_req = 1;
        wait(~o_ready);
        s_set_sda = 1;
        s_set_scl = 1;
        wait(o_done);
        wait_cycles(1);
        `ASSERT(sda == 0)
        `ASSERT(scl == 0)
        i_req = 0;
        wait_cycles(4);
        `ASSERT(sda == 0)
        `ASSERT(scl == 0)
        wait_cycles(4);
    end
    `UNIT_TEST_END
    `UNIT_TEST("Other_master_start")
    #1ns;
    begin
        wait_cycles(4);
        s_set_sda = 0;
        s_set_scl = 1;
        wait_cycles(1);
        i_req = 1;
        wait_cycles(1);
        repeat(4) begin
            `ASSERT(o_ready == 1'b0)
            wait_cycles(1);
        end
        wait_cycles(4);
    end
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
