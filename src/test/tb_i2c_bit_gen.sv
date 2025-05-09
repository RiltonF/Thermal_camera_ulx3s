// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "i2c_bit_gen.sv"
`timescale 1 ns / 100 ps
`default_nettype none

module tb_i2c_bit_gen();

    `SVUT_SETUP

    parameter int CLK_FREQ = 25_000_000;
    parameter int I2C_FREQ = 100_0000;

    logic clk=1;
    logic rst=1;
    logic       i_req;
    logic       i_we;
    logic       i_wr_bit;
    logic       o_ready;
    logic       o_rd_valid;
    logic       o_rd_bit;
    logic o_sda_drive;
    logic o_scl_drive;
    wire sda, scl;
    logic s_set_sda;
    logic s_set_scl;

    pullup(sda);
    pullup(scl);

    assign sda = s_set_sda ? 1'bz : 1'b0;
    assign scl = s_set_scl ? 1'bz : 1'b0;

    assign sda = o_sda_drive ? 1'bz : 1'b0;
    assign scl = o_scl_drive ? 1'bz : 1'b0;

    i2c_bit_gen 
    #(
    .CLK_FREQ (CLK_FREQ),
    .I2C_FREQ (I2C_FREQ)
    )
    dut 
    (
    .i_clk      (clk),
    .i_rst      (rst),
    .i_enable   (1'b1), //this will be tested later in the arbitration phase
    .i_req      (i_req),
    .i_we       (i_we),
    .i_wr_bit   (i_wr_bit),
    .o_ready    (o_ready),
    .o_rd_valid (o_rd_valid),
    .o_rd_bit   (o_rd_bit),
    .o_sda_drive(o_sda_drive),
    .o_scl_drive(o_scl_drive),
    .i_sda(sda),
    .i_scl(scl)
    );

    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    //Clocks
    always #(5ns) clk= ~clk; // verilator lint_off STMTDLY

    // To dump data for visualization:
    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, tb_i2c_bit_gen);
    end
    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        rst = 1;
        i_req = '0;
        i_we = '0;
        i_wr_bit = '0;
        s_set_sda = 1;
        s_set_scl = 1;
        wait_cycles(4);
        rst = 0;
    end
    endtask

    // teardown() runs when a test ends
    task teardown(msg="");
    begin
        wait_cycles(4);
        rst = 1;
        i_req = '0;
        s_set_sda = 1;
        s_set_scl = 1;
        wait_cycles(4);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")

    `UNIT_TEST("Clock stretching")
        #1ns;
        begin
            i_we = 0;
            i_wr_bit = 0;
            s_set_sda = 0;
            wait_cycles(4);
            repeat(8) begin
                i_req = 1;
                wait(~o_ready);
                wait(scl == 1'b0);
                s_set_sda = ~s_set_sda;
                wait(scl == 1'b1);
                s_set_scl = 0; //clock stretching
                wait_cycles(20);
                s_set_scl = 1; //clock release
                wait(o_rd_valid);
                `ASSERT(o_rd_bit == sda)
                wait(o_ready);
            end
        end
    `UNIT_TEST_END
    `UNIT_TEST("Read and write")
        #1ns;
        begin
            i_we = 1;
            i_wr_bit = 0;
            wait_cycles(4);
            repeat(8) begin
                i_req = 1;
                //write
                wait(~o_ready);
                i_wr_bit = ~i_wr_bit;
                i_we = ~i_we; //set next req to read
                wait(scl == 1'b1);
                `ASSERT(sda == ~i_wr_bit) //check write
                wait(o_ready); //next request, read
                wait(~o_ready);
                wait(o_rd_valid);
                `ASSERT(o_rd_bit == sda)
                i_we = ~i_we; //set next req to write
                wait(o_ready);
            end
        end
    `UNIT_TEST_END
    `UNIT_TEST("Read")
        #1ns;
        begin
            i_we = 0;
            i_wr_bit = 0;
            s_set_sda = 0;
            wait_cycles(4);
            repeat(8) begin
                i_req = 1;
                wait(~o_ready);
                wait(scl == 1'b0);
                s_set_sda = ~s_set_sda;
                wait(o_rd_valid);
                `ASSERT(o_rd_bit == sda)
                wait(o_ready);
            end
        end
    `UNIT_TEST_END
    `UNIT_TEST("Write")
        #1ns;
        begin
            i_we = 1;
            i_wr_bit = 0;
            wait_cycles(4);
            repeat(8) begin
                i_req = 1;
                wait(~o_ready);
                i_wr_bit = ~i_wr_bit;
                wait(scl == 1'b1);
                wait(scl == 1'b0);
                `ASSERT(sda == ~i_wr_bit)
                wait(o_ready);
            end
        end
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
