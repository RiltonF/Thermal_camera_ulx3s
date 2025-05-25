// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "i2c_req_manager_16bit.sv"
`timescale 1 ns / 100 ps

module tb_i2c_req_manager_16bit();

    `SVUT_SETUP

    parameter int BURST_WIDTH = 4;

    logic clk=1;
    logic rst=1;
    logic i_enable;
    logic i_valid;
    logic i_we;
    logic i_sccb_mode;
    logic [6:0] i_addr_slave;
    logic [15:0] i_addr_reg;
    logic [BURST_WIDTH-1:0] i_burst_num;
    logic o_ready;
    logic i_valid_wr_byte;
    logic [15:0] i_wr_byte;
    logic o_ready_wr_byte;
    logic [7:0] o_wr_byte;
    logic i_ready_rd_byte;
    logic i_byte_ready;
    logic i_wr_ack;
    logic i_wr_nack;
    logic i_rd_valid;
    logic i_start_ready;
    logic i_stop_ready;
    logic i_start_done;
    logic i_stop_done;
    t_gen_states o_active_gen;
    t_gen_states o_active_gen_next;
    logic        o_req_valid;
    logic        o_req_we;
    logic        o_req_last_byte;

    i2c_req_manager_16bit
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
    .i_ready_rd_byte   (i_ready_rd_byte),
    .i_wr_byte         (i_wr_byte),
    .o_ready_wr_byte   (o_ready_wr_byte),
    .o_wr_byte         (o_wr_byte),
    .i_byte_ready      (i_byte_ready),
    .i_wr_ack          (i_wr_ack),
    .i_wr_nack         (i_wr_nack),
    .i_rd_valid        (i_rd_valid),
    .i_start_ready     (i_start_ready),
    .i_stop_ready      (i_stop_ready),
    .i_start_done     (i_start_done),
    .i_stop_done      (i_stop_done),
    .o_active_gen      (o_active_gen),
    .o_active_gen_next (o_active_gen_next),
    .o_req_valid       (o_req_valid),
    .o_req_we          (o_req_we),
    .o_req_last_byte   (o_req_last_byte)
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
        $dumpvars(0, tb_i2c_req_manager_16bit);
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
        i_start_ready = 0;
        i_stop_ready = 0;
        i_start_done = 0;
        i_stop_done = 0;
        wait_cycles(8);
        rst = 0;
        i_ready_rd_byte = 1;
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

    // TODO: FIX broken read tests after chang to read mode

    `TEST_SUITE("TESTSUITE_NAME")
    //
    // `UNIT_TEST("Repeat start")
    //     #1ns;
    //     wait_cycles(4);
    //     i_enable = 1;
    //     i_we = 0;
    //     i_sccb_mode = 0;
    //     i_addr_slave = 'hff;
    //     i_addr_reg = 'h0f;
    //     i_burst_num = 0;
    //     i_wr_byte = 'hcd;
    //     i_valid_wr_byte = 1;
    //
    //     i_start_ready = 1;
    //     i_stop_ready = 1;
    //     i_byte_ready = 1;
    //     wait_cycles(4);
    //
    //     fork
    //         begin
    //             repeat (3) begin
    //                 i_valid = 1;
    //                 `WAIT(~o_ready);
    //                 wait_cycles(1);
    //                 // i_valid = 0;
    //                 i_we = ~i_we;
    //                 `WAIT(o_ready);
    //                 wait_cycles(1);
    //             end
    //                 i_valid = 0;
    //         end
    //         begin
    //             repeat (4) begin
    //                 //START
    //                 `WAIT(o_req_valid);
    //                 `ASSERT(o_active_gen == START)
    //                 wait_cycles(4);
    //                 i_start_done = 1;
    //                 wait_cycles(1);
    //                 i_start_done = 0;
    //
    //                 //BYTE
    //                 //2+data bursts
    //                 for(int i = 0;i<3;i++) begin
    //                     `WAIT(o_req_valid);
    //                     `ASSERT(o_active_gen == BYTE)
    //                     if(i == 0) begin
    //                         `ASSERT(o_wr_byte == {i_addr_slave, 1'b0})
    //                     end else if(i == 1) begin
    //                         `ASSERT(o_wr_byte == i_addr_reg)
    //                     end else if(o_req_we) begin
    //                         `ASSERT(o_wr_byte == i_wr_byte)
    //                     end
    //
    //                     if (i < 2 | dut.s_r.write_en) begin
    //                         wait_cycles(4);
    //                         i_wr_ack = 1;
    //                         wait_cycles(1);
    //                         i_wr_ack = 0;
    //                     end
    //                     else begin
    //                         wait_cycles(4);
    //                         i_rd_valid = 1;
    //                         wait_cycles(1);
    //                         i_rd_valid = 0;
    //                     end
    //                 end
    //             end
    //             `WAIT(o_req_valid);
    //             `ASSERT(o_active_gen == STOP)
    //             wait_cycles(4);
    //             i_stop_done = 1;
    //             wait_cycles(1);
    //             i_stop_done = 0;
    //         end
    //         begin
    //             repeat (2) begin
    //                 `WAIT(o_ready_wr_byte);
    //                 wait_cycles(1);
    //                 i_wr_byte = ~i_wr_byte;
    //                 wait_cycles(1);
    //             end
    //             i_valid_wr_byte = 0;
    //         end
    //     join
    //
    // `UNIT_TEST_END
    //
    // `UNIT_TEST("Byte write multiple SCCB")
    //     wait_cycles(4);
    //     i_enable = 1;
    //     i_we = 1;
    //     i_sccb_mode = 1;
    //     i_addr_slave = 'hff;
    //     i_addr_reg = 'h0f;
    //     i_burst_num = 7; //this should be ignored in sccb mode
    //     i_wr_byte = 'hcd;
    //     i_valid_wr_byte = 1;
    //
    //     i_start_ready = 1;
    //     i_stop_ready = 1;
    //     i_byte_ready = 1;
    //     wait_cycles(4);
    //
    //     fork
    //         begin
    //             repeat (4) begin
    //                 i_valid = 1;
    //                 `WAIT(~o_ready);
    //                 wait_cycles(1);
    //                 i_valid = 0;
    //                 `WAIT(o_ready);
    //                 wait_cycles(1);
    //             end
    //         end
    //         repeat (4) begin
    //             //START
    //             `WAIT(o_req_valid);
    //             `ASSERT(o_active_gen == START)
    //             wait_cycles(4);
    //             i_start_done = 1;
    //             wait_cycles(1);
    //             i_start_done = 0;
    //
    //             //BYTE
    //             //2+data bursts
    //             for(int i = 0;i<3;i++) begin
    //                 `WAIT(o_req_valid);
    //                 `ASSERT(o_active_gen == BYTE)
    //                 if(i == 0) begin
    //                     `ASSERT(o_wr_byte == {i_addr_slave, 1'b0})
    //                 end else if(i == 1) begin
    //                     `ASSERT(o_wr_byte == i_addr_reg)
    //                 end else begin
    //                     `ASSERT(o_wr_byte == i_wr_byte)
    //                 end
    //                 if (i < 2 | i_we) begin
    //                     wait_cycles(4);
    //                     i_wr_ack = 1;
    //                     wait_cycles(1);
    //                     i_wr_ack = 0;
    //                 end else begin
    //                     wait_cycles(4);
    //                     i_rd_valid = 1;
    //                     wait_cycles(1);
    //                     i_rd_valid = 0;
    //                 end
    //             end
    //
    //             //STOP
    //             `WAIT(o_req_valid);
    //             `ASSERT(o_active_gen == STOP)
    //             wait_cycles(4);
    //             i_stop_done = 1;
    //             wait_cycles(1);
    //             i_stop_done = 0;
    //         end
    //         begin
    //             repeat (4) begin
    //                 `WAIT(o_ready_wr_byte);
    //                 wait_cycles(1);
    //                 i_wr_byte = ~i_wr_byte;
    //                 wait_cycles(1);
    //             end
    //         end
    //     join
    //
    // `UNIT_TEST_END
    //
    //
    // `UNIT_TEST("Byte read multiple")
    //     #1ns;
    //     wait_cycles(4);
    //     i_enable = 1;
    //     i_we = 0;
    //     i_sccb_mode = 0;
    //     i_addr_slave = 'hff;
    //     i_addr_reg = 'h0f;
    //     i_burst_num = 5;
    //     i_wr_byte = 'hcd;
    //     i_valid_wr_byte = 1;
    //
    //     i_start_ready = 1;
    //     i_stop_ready = 1;
    //     i_byte_ready = 1;
    //     wait_cycles(4);
    //
    //     fork
    //         begin
    //             //START
    //             i_valid = 1;
    //             `WAIT(~o_ready);
    //             i_valid = 0;
    //             `WAIT(o_req_valid);
    //             `ASSERT(o_active_gen == START)
    //             wait_cycles(4);
    //             i_start_done = 1;
    //             wait_cycles(1);
    //             i_start_done = 0;
    //
    //             //BYTE
    //             //2+1+data bursts
    //             for(int i = 0;i<8;i++) begin
    //                 `WAIT(o_req_valid);
    //                 `ASSERT(o_active_gen == BYTE)
    //                 if(i == 0) begin
    //                     `ASSERT(o_wr_byte == {i_addr_slave, 1'b0})
    //                 end else if(i == 1) begin
    //                     `ASSERT(o_wr_byte == i_addr_reg)
    //                 end else if (i_we)begin
    //                     `ASSERT(o_wr_byte == i_wr_byte)
    //                 end
    //                 if (i < 2 | i_we) begin
    //                     wait_cycles(4);
    //                     i_wr_ack = 1;
    //                     wait_cycles(1);
    //                     i_wr_ack = 0;
    //                 end else begin
    //                     wait_cycles(4);
    //                     i_rd_valid = 1;
    //                     wait_cycles(1);
    //                     i_rd_valid = 0;
    //                 end
    //             end
    //             `WAIT(o_req_valid);
    //             `ASSERT(o_active_gen == STOP)
    //             wait_cycles(4);
    //             i_stop_done = 1;
    //             wait_cycles(1);
    //             i_stop_done = 0;
    //             wait_cycles(4);
    //             `ASSERT(o_ready == 1)
    //             wait_cycles(6);
    //         end
    //     join
    //
    // `UNIT_TEST_END
    //

    `UNIT_TEST("Byte write multiple 2")
        #1ns;
        wait_cycles(4);
        i_enable = 1;
        i_we = 1;
        i_sccb_mode = 0;
        i_addr_slave = 'hff;
        i_addr_reg = 'hf00f;
        i_burst_num = 7;
        i_wr_byte = 'habcd;
        i_valid_wr_byte = 1;

        i_start_ready = 1;
        i_stop_ready = 1;
        i_byte_ready = 1;
        wait_cycles(4);

        fork
            begin
                //START
                i_valid = 1;
                `WAIT(~o_ready);
                i_valid = 0;
                `WAIT(o_req_valid);
                `ASSERT(o_active_gen == START)
                wait_cycles(4);
                i_start_done = 1;
                wait_cycles(1);
                i_start_done = 0;

                //BYTE
                for(int i = 0;i<(1+2+2*(i_burst_num+1));i++) begin
                    `WAIT(o_req_valid);
                    `ASSERT(o_active_gen == BYTE)
                    case(i)
                        0:begin `ASSERT(o_wr_byte == {i_addr_slave, 1'b0}) end
                        1:begin `ASSERT(o_wr_byte == i_addr_reg[15:8]) end
                        2:begin `ASSERT(o_wr_byte == i_addr_reg[7:0]) end
                        default: begin
                        `ASSERT(o_wr_byte == (i[0]) ? i_wr_byte[15:8]:i_wr_byte[7:0])
                        end
                    endcase
                    if (i < 3 | i_we) begin
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
                `WAIT(o_req_valid);
                `ASSERT(o_active_gen == STOP)
                wait_cycles(4);
                i_stop_done = 1;
                wait_cycles(1);
                i_stop_done = 0;
                wait_cycles(2);
                `ASSERT(o_active_gen == STOP)
                wait_cycles(6);
            end
            begin
                repeat (i_burst_num+1) begin
                    `WAIT(o_ready_wr_byte);
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
        i_addr_reg = 'hf00f;
        i_burst_num = 4;
        i_wr_byte = 'habcd;
        i_valid_wr_byte = 1;
        wait_cycles(4);
        i_start_ready = 1;
        wait_cycles(1);
        i_valid = 0;
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_done = 1;
        wait_cycles(1);
        i_start_done = 0;
        repeat (5+i_burst_num*2) begin
            i_byte_ready = 1;
            `WAIT(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            // i_wr_byte = ~i_wr_byte;
            wait_cycles(4);
            i_wr_ack = 1;
            wait_cycles(1);
            i_wr_ack = 0;
        end
        i_stop_ready = 1;
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(4);
        i_stop_done = 1;
        wait_cycles(1);
        i_stop_done = 0;
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
        i_addr_reg = 'hf00f;
        i_burst_num = 0;
        i_wr_byte = 'habcd;
        i_valid_wr_byte = 1;
        wait_cycles(4);
        i_start_ready = 1;
        wait_cycles(1);
        i_valid = 0;
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_done = 1;
        wait_cycles(1);
        i_start_done = 0;
        repeat (5) begin
            i_byte_ready = 1;
            `WAIT(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_wr_ack = 1;
            wait_cycles(1);
            i_wr_ack = 0;
        end
        // `WAIT(o_req_valid);
        // `ASSERT(o_active_gen == BYTE)
        // wait_cycles(4);
        // i_rd_valid = 1;
        // wait_cycles(1);
        // i_rd_valid = 0;
        i_stop_ready = 1;
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(4);
        i_stop_done = 1;
        wait_cycles(1);
        i_stop_done = 0;
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
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_done = 1;
        wait_cycles(1);
        i_start_done = 0;
        repeat (3) begin
            i_byte_ready = 1;
            `WAIT(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_wr_ack = 1;
            wait_cycles(1);
            i_wr_ack = 0;
        end
        //start again in read mode
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_done = 1;
        wait_cycles(1);
        i_start_done = 0;
        //wr slave addr, and read data
        i_byte_ready = 1;
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == BYTE)
        wait_cycles(4);
        i_wr_ack = 1;
        wait_cycles(1);
        i_wr_ack = 0;
        repeat (2*(i_burst_num+1)) begin
            `WAIT(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_rd_valid = 1;
            wait_cycles(1);
            i_rd_valid = 0;
        end
        i_stop_ready = 1;
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(4);
        i_stop_done = 1;
        wait_cycles(1);
        i_stop_done = 0;
        wait_cycles(2);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(6);
    `UNIT_TEST_END


    `UNIT_TEST("Byte read sccb")
        #1ns;
        wait_cycles(4);
        i_enable = 1;
        i_valid = 1;
        i_we = 0;
        i_sccb_mode = 1;
        i_addr_slave = 'hff;
        i_addr_reg = 'hf00f;
        i_burst_num = 0;
        wait_cycles(4);
        i_start_ready = 1;
        i_stop_ready = 1;
        wait_cycles(1);
        i_valid = 0;
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_done = 1;
        wait_cycles(1);
        i_start_done = 0;
        repeat (3) begin
            i_byte_ready = 1;
            `WAIT(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_wr_ack = 1;
            wait_cycles(1);
            i_wr_ack = 0;
        end
        //stop
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(4);
        i_stop_done = 1;
        wait_cycles(1);
        i_stop_done = 0;
        //start again in read mode
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_done = 1;
        wait_cycles(1);
        i_start_done = 0;
        //wr slave addr, and read data 2 bytes
        i_byte_ready = 1;
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == BYTE)
        wait_cycles(4);
        i_wr_ack = 1;
        wait_cycles(1);
        i_wr_ack = 0;
        repeat (2) begin
            `WAIT(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_rd_valid = 1;
            wait_cycles(1);
            i_rd_valid = 0;
        end
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(4);
        i_stop_done = 1;
        wait_cycles(1);
        i_stop_done = 0;
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
        i_addr_reg = 'hf00f;
        i_burst_num = 0;
        wait_cycles(4);
        i_start_ready = 1;
        i_stop_ready = 1;
        wait_cycles(1);
        i_valid = 0;
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_done = 1;
        wait_cycles(1);
        i_start_done = 0;
        repeat (3) begin
            i_byte_ready = 1;
            `WAIT(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_wr_ack = 1;
            wait_cycles(1);
            i_wr_ack = 0;
        end
        // //stop
        // `WAIT(o_req_valid);
        // `ASSERT(o_active_gen == STOP)
        // wait_cycles(4);
        // i_stop_done = 1;
        // wait_cycles(1);
        // i_stop_done = 0;
        //start again in read mode
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == START)
        wait_cycles(4);
        i_start_done = 1;
        wait_cycles(1);
        i_start_done = 0;
        //wr slave addr, and read data 2 bytes
        i_byte_ready = 1;
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == BYTE)
        wait_cycles(4);
        i_wr_ack = 1;
        wait_cycles(1);
        i_wr_ack = 0;
        repeat (2) begin
            `WAIT(o_req_valid);
            `ASSERT(o_active_gen == BYTE)
            wait_cycles(4);
            i_rd_valid = 1;
            wait_cycles(1);
            i_rd_valid = 0;
        end
        `WAIT(o_req_valid);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(4);
        i_stop_done = 1;
        wait_cycles(1);
        i_stop_done = 0;
        wait_cycles(2);
        `ASSERT(o_active_gen == STOP)
        wait_cycles(6);
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
