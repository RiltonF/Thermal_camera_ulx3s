// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "i2c_req_manager.sv"
`timescale 1 ns / 100 ps

module tb_i2c_req_manager();

    `SVUT_SETUP

    parameter int BURST_WIDTH = 4;

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
    logic i_valid_wr_byte;
    logic [7:0] i_wr_byte;
    logic o_ready_wr_byte;
    logic [7:0] o_wr_byte;
    logic i_byte_ready;
    logic i_wr_ack;
    logic i_wr_nack;
    logic i_rd_valid;
    logic i_start_stop_done;
    logic i_start_ready;
    logic i_stop_ready;
    t_gen_states o_active_gen;
    t_gen_states o_active_gen_next;
    logic        o_req_valid;
    logic        o_req_we;
    logic        o_req_last_byte;

    i2c_req_manager
    #(
    .BURST_WIDTH (BURST_WIDTH)
    )
    dut
    (
    .i_clk             (clk),
    .i_rst             (rst),
   .i_enable          (i_enable),
    .i_valid           (i_valid),
    .i_we              (i_we),
    .i_sccb_mode       (i_sccb_mode),
    .i_addr_slave      (i_addr_slave),
    .i_addr_reg        (i_addr_reg),
    .i_burst_num       (i_burst_num),
    .o_ready           (o_ready),
    .i_valid_wr_byte   (i_valid_wr_byte),
    .i_wr_byte         (i_wr_byte),
    .o_ready_wr_byte   (o_ready_wr_byte),
    .o_wr_byte         (o_wr_byte),
    .i_byte_ready      (i_byte_ready),
    .i_wr_ack          (i_wr_ack),
    .i_wr_nack         (i_wr_nack),
    .i_rd_valid        (i_rd_valid),
    .i_start_stop_done (i_start_stop_done),
    .i_start_ready     (i_start_ready),
    .i_stop_ready      (i_stop_ready),
    .o_active_gen      (o_active_gen),
    .o_active_gen_next (o_active_gen_next),
    .o_req_valid       (o_req_valid),
    .o_req_we          (o_req_we),
    .o_req_last_byte   (o_req_last_byte)
    );

    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    //Clocks
    always #(5ns) clk= ~clk; // verilator lint_off STMTDLY

    // To dump data for visualization:
    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, tb_i2c_req_manager);
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
        i_valid_wr_byte = 0;
        i_wr_byte = 0;
        i_byte_ready = 0;
        i_wr_ack = 0;
        i_wr_nack = 0;
        i_rd_valid = 0;
        i_start_stop_done = 0;
        i_start_ready = 0;
        i_stop_ready = 0;
        wait_cycles(8);
        rst = 0;
    end
    endtask

    task teardown(msg="");
    begin
        // teardown() runs when a test ends
        wait_cycles(4);
        rst = 1;
        wait_cycles(4);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")

    `UNIT_TEST("Byte write multiple SCCB")
        #1ns;
        wait_cycles(4);
        i_enable = 1;
        i_we = 1;
        i_sccb_mode = 1;
        i_addr_slave = 'hff;
        i_addr_reg = 'h0f;
        i_burst_num = 7; //this should be ignored in sccb mode
        i_wr_byte = 'hcd;
        i_valid_wr_byte = 1;

        i_start_ready = 1;
        i_stop_ready = 1;
        i_byte_ready = 1;
        wait_cycles(4);

        fork
            begin
                repeat (4) begin
                    i_valid = 1;
                    wait(~o_ready);
                    wait_cycles(1);
                    i_valid = 0;
                    wait(o_ready);
                    wait_cycles(1);
                end
            end
            repeat (4) begin
                //START
                wait(o_req_valid);
                `ASSERT(o_active_gen == START)
                wait_cycles(4);
                i_start_stop_done = 1;
                wait_cycles(1);
                i_start_stop_done = 0;

                //BYTE
                //2+data bursts
                for(int i = 0;i<3;i++) begin
                    wait(o_req_valid);
                    `ASSERT(o_active_gen == BYTE)
                    if(i == 0) `ASSERT(o_wr_byte == {i_addr_slave, ~i_we})
                    else if(i == 1) `ASSERT(o_wr_byte == i_addr_reg)
                    else `ASSERT(o_wr_byte == i_wr_byte)
                    if (i < 2 | i_we) begin
                        wait_cycles(4);
                        i_wr_ack = 1;
                        wait_cycles(1);
                        i_wr_ack = 0;
                    end else begin
                        wait_cycles(4);
                        i_rd_valid = 1;
                        wait_cycles(1);
                        i_rd_valid = 0;
                    end
                end
                wait(o_req_valid);
                `ASSERT(o_active_gen == STOP)
                wait_cycles(4);
                i_start_stop_done = 1;
                wait_cycles(1);
                i_start_stop_done = 0;
            end
            begin
                repeat (4) begin
                    wait(o_ready_wr_byte);
                    wait_cycles(1);
                    i_wr_byte = ~i_wr_byte;
                    wait_cycles(1);
                end
            end
        join

    `UNIT_TEST_END


    `UNIT_TEST("Byte write multiple 2")
        #1ns;
        wait_cycles(4);
        i_enable = 1;
        i_we = 1;
        i_sccb_mode = 0;
        i_addr_slave = 'hff;
        i_addr_reg = 'h0f;
        i_burst_num = 7; //this should be ignored in sccb mode
        i_wr_byte = 'hcd;
        i_valid_wr_byte = 1;

        i_start_ready = 1;
        i_stop_ready = 1;
        i_byte_ready = 1;
        wait_cycles(4);

        fork
            begin
                //START
                i_valid = 1;
                wait(~o_ready);
                i_valid = 0;
                wait(o_req_valid);
                `ASSERT(o_active_gen == START)
                wait_cycles(4);
                i_start_stop_done = 1;

                //BYTE
                //2+data bursts
                for(int i = 0;i<9;i++) begin
                    wait(o_req_valid);
                    `ASSERT(o_active_gen == BYTE)
                    if(i == 0) `ASSERT(o_wr_byte == {i_addr_slave, ~i_we})
                    else if(i == 1) `ASSERT(o_wr_byte == i_addr_reg)
                    else `ASSERT(o_wr_byte == i_wr_byte)
                    if (i < 2 | i_we) begin
                        wait_cycles(4);
                        i_wr_ack = 1;
                        wait_cycles(1);
                        i_wr_ack = 0;
                    end else begin
                        wait_cycles(4);
                        i_rd_valid = 1;
                        wait_cycles(1);
                        i_rd_valid = 0;
                    end
                end
                wait(o_req_valid);
                `ASSERT(o_active_gen == STOP)
                wait_cycles(4);
                i_start_stop_done = 1;
                wait_cycles(1);
                i_start_stop_done = 0;
                wait_cycles(2);
                `ASSERT(o_active_gen == STOP)
                wait_cycles(6);
            end
            begin
                repeat (7) begin
                    wait(o_ready_wr_byte);
                    wait_cycles(1);
                    i_wr_byte = ~i_wr_byte;
                    wait_cycles(1);
                end
            end
        join

    `UNIT_TEST_END

    `UNIT_TEST("Byte write multiple")
        #1ns;
        wait_cycles(4);
        i_enable = 1;
        i_valid = 1;
        i_we = 1;
        i_sccb_mode = 0;
        i_addr_slave = 'hff;
        i_addr_reg = 'h0f;
        i_burst_num = 4;
        i_wr_byte = 'hcd;
        i_valid_wr_byte = 1;
        wait_cycles(4);
        i_start_ready = 1;
        wait_cycles(1);
        i_valid = 0;
        wait(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_stop_done = 1;
        wait_cycles(1);
        i_start_stop_done = 0;
        repeat (6) begin
            i_byte_ready = 1;
            wait(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            i_wr_byte = ~i_wr_byte;
            wait_cycles(4);
            i_wr_ack = 1;
            wait_cycles(1);
            i_wr_ack = 0;
        end
        i_stop_ready = 1;
        wait(o_req_valid);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(4);
        i_start_stop_done = 1;
        wait_cycles(1);
        i_start_stop_done = 0;
        wait_cycles(2);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(6);
    `UNIT_TEST_END


    `UNIT_TEST("Byte write")
        #1ns;
        wait_cycles(4);
        i_enable = 1;
        i_valid = 1;
        i_we = 1;
        i_sccb_mode = 0;
        i_addr_slave = 'hff;
        i_addr_reg = 'h0f;
        i_burst_num = 0;
        i_wr_byte = 'hcd;
        i_valid_wr_byte = 1;
        wait_cycles(4);
        i_start_ready = 1;
        wait_cycles(1);
        i_valid = 0;
        wait(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_stop_done = 1;
        wait_cycles(1);
        i_start_stop_done = 0;
        repeat (3) begin
            i_byte_ready = 1;
            wait(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_wr_ack = 1;
            wait_cycles(1);
            i_wr_ack = 0;
        end
        // wait(o_req_valid);
        // `ASSERT(o_active_gen == BYTE)
        // wait_cycles(4);
        // i_rd_valid = 1;
        // wait_cycles(1);
        // i_rd_valid = 0;
        i_stop_ready = 1;
        wait(o_req_valid);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(4);
        i_start_stop_done = 1;
        wait_cycles(1);
        i_start_stop_done = 0;
        wait_cycles(2);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(6);
    `UNIT_TEST_END


    `UNIT_TEST("Byte read multiple")
        #1ns;
        wait_cycles(4);
        i_enable = 1;
        i_valid = 1;
        i_we = 0;
        i_sccb_mode = 0;
        i_addr_slave = 'hff;
        i_addr_reg = 'h0f;
        i_burst_num = 3;
        wait_cycles(4);
        i_start_ready = 1;
        wait_cycles(1);
        i_valid = 0;
        wait(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_stop_done = 1;
        wait_cycles(1);
        i_start_stop_done = 0;
        repeat (2) begin
            i_byte_ready = 1;
            wait(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_wr_ack = 1;
            wait_cycles(1);
            i_wr_ack = 0;
        end
        repeat (4) begin
            wait(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_rd_valid = 1;
            wait_cycles(1);
            i_rd_valid = 0;
        end
        i_stop_ready = 1;
        wait(o_req_valid);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(4);
        i_start_stop_done = 1;
        wait_cycles(1);
        i_start_stop_done = 0;
        wait_cycles(2);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(6);
    `UNIT_TEST_END


    `UNIT_TEST("Byte read")
        #1ns;
        wait_cycles(4);
        i_enable = 1;
        i_valid = 1;
        i_we = 0;
        i_sccb_mode = 0;
        i_addr_slave = 'hff;
        i_addr_reg = 'h0f;
        i_burst_num = 0;
        wait_cycles(4);
        i_start_ready = 1;
        wait_cycles(1);
        i_valid = 0;
        wait(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_stop_done = 1;
        wait_cycles(1);
        i_start_stop_done = 0;
        repeat (2) begin
            i_byte_ready = 1;
            wait(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_wr_ack = 1;
            wait_cycles(1);
            i_wr_ack = 0;
        end
        wait(o_req_valid);
        `ASSERT(o_active_gen == BYTE)
        wait_cycles(4);
        i_rd_valid = 1;
        wait_cycles(1);
        i_rd_valid = 0;
        i_stop_ready = 1;
        wait(o_req_valid);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(4);
        i_start_stop_done = 1;
        wait_cycles(1);
        i_start_stop_done = 0;
        wait_cycles(2);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(6);
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
