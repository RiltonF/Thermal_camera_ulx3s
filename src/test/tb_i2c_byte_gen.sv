// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "i2c_byte_gen.sv"
`include "i2c_bit_gen.sv"
`timescale 1 ns / 100 ps
`default_nettype none

module tb_i2c_byte_gen();

    `SVUT_SETUP

    parameter int CLK_FREQ = 25_000_000;
    parameter int I2C_FREQ = 100_0000;

    logic clk=1;
    logic rst=1;
    logic i_req;
    logic i_we;
    logic [7:0] i_wr_byte;
    logic i_rd_last;
    logic o_ready;
    logic o_wr_ack;
    logic o_wr_nack;
    logic o_rd_valid;
    logic [7:0] o_rd_byte;
    logic o_req_bit;
    logic o_we_bit;
    logic o_wr_bit;
    logic i_ready_bit;
    logic i_rd_valid_bit;
    logic i_rd_bit;

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

    i2c_byte_gen 
    #(
    .CLK_FREQ (CLK_FREQ),
    .I2C_FREQ (I2C_FREQ)
    )
    dut 
    (
    .i_clk          (clk),
    .i_rst          (rst),
    .i_req          (i_req),
    .i_we           (i_we),
    .i_wr_byte      (i_wr_byte),
    .i_rd_last      (i_rd_last),
    .o_ready        (o_ready),
    .o_wr_ack       (o_wr_ack),
    .o_wr_nack       (o_wr_nack),
    .o_rd_valid     (o_rd_valid),
    .o_rd_byte      (o_rd_byte),
    .o_req_bit      (o_req_bit),
    .o_we_bit       (o_we_bit),
    .o_wr_bit       (o_wr_bit),
    .i_ready_bit    (i_ready_bit),
    .i_rd_valid_bit (i_rd_valid_bit),
    .i_rd_bit       (i_rd_bit)
    );

    i2c_bit_gen 
    #(
    .CLK_FREQ (CLK_FREQ),
    .I2C_FREQ (I2C_FREQ)
    )
    inst_bit_gen 
    (
    .i_clk      (clk),
    .i_rst      (rst),
    .i_req      (o_req_bit),
    .i_we       (o_we_bit),
    .i_wr_bit   (o_wr_bit),
    .o_ready    (i_ready_bit),
    .o_rd_valid (i_rd_valid_bit),
    .o_rd_bit   (i_rd_bit),

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
        $dumpvars(0, tb_i2c_byte_gen);
    end

    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        rst = 1;
        s_set_sda = 1;
        s_set_scl = 1;
        i_rd_last = 0;
        i_req = '0;
        i_we = '0;
        i_wr_byte = '0;
        wait_cycles(4);
        rst = 0;
    end
    endtask

    task teardown(msg="");
    begin
        wait_cycles(4);
        rst = 1;
        s_set_sda = 1;
        s_set_scl = 1;
        i_req = '0;
        i_we = '0;
        i_wr_byte = '0;
        wait_cycles(4);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")

    `UNIT_TEST("write_data")
        #1ns;
        fork
        static logic [7:0] c_rd_data = 8'b1001_0101;
        begin
            for(int i=0; i<4;i++) begin : write_slave_ack_gen
                wait(o_ready);
                wait(~o_ready);
                wait(dut.s_r.bit_counter == 8);
                wait(scl == 0);
                //send slave ack
                s_set_sda = i%2; //alternate ack/nack
                wait(scl == 1);
                wait(scl == 0);
                s_set_sda = 1;
            end
        end
        begin
            wait(o_ready);
            for(int i=0; i<4;i++) begin
                i_req = 1;
                i_we = 1;
                i_wr_byte = c_rd_data;
                wait(~o_ready);
                if (i%2) begin
                    wait(o_wr_nack);
                    `ASSERT(o_wr_nack == 1);
                end else begin
                    wait(o_wr_ack);
                    `ASSERT(o_wr_ack == 1);
                end
                i_req = ~(i==3);
                wait(o_ready);
            end
        end
        join
        wait_cycles(10);
    `UNIT_TEST_END
    `UNIT_TEST("read_multi_ack_nack_2")
        #1ns;
        fork
        static logic [7:0] c_rd_data = 8'b1001_0101;
        begin
            repeat (4) begin : read_data_gen
                wait(o_ready);
                wait(~o_ready);
                for (int i=0;i<8;i++) begin
                    wait(scl == 0);
                    //feed the data in reverse
                    s_set_sda = c_rd_data[7-i];
                    wait(scl == 1);
                end
                wait(scl == 0);
                s_set_sda = 1;
            end
        end
        begin
            wait(o_ready);
            for(int i=0; i<4;i++) begin
                i_req = 1;
                i_we = 0;
                i_rd_last = (i==3); //used for nack on last req
                wait(~o_ready);
                wait(dut.s_r.bit_counter == 8);
                wait(scl == 0);
                wait(scl == 1);
                `ASSERT(sda == i_rd_last);
                i_req = ~(i==3);
                wait(o_rd_valid);
                `ASSERT(o_rd_byte == c_rd_data);
                wait(o_ready);
            end
        end
        join
        wait_cycles(10);
    `UNIT_TEST_END
    `UNIT_TEST("read_multi_ack_nack")
        #1ns;
        wait_cycles(4);
        wait(o_ready);
        for(int i=0; i<4;i++) begin
            i_req = 1;
            i_we = 0;
            i_rd_last = (i==3); //used for nack on last req
            wait(~o_ready);
            wait(dut.s_r.bit_counter == 8);
            wait(scl == 0);
            wait(scl == 1);
            `ASSERT(sda == i_rd_last);
            i_req = ~(i==3);
            wait(o_rd_valid);
            `ASSERT(o_rd_byte == 8'hff);
            wait(o_ready);
        end
        wait_cycles(10);
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
