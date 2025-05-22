// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`define SIMULATION
`include "sobel_filter.sv"
`include "mu_ram_1r1w.v"
`timescale 1 ns / 100 ps

module tb_sobel_filter();

    `SVUT_SETUP

    // parameter int p_x_max = 32;
    // parameter int p_y_max = 24;
    parameter int p_x_max = 160;
    parameter int p_y_max = 120;
    parameter int p_data_width = 8;
    localparam int c_x_width = $clog2(p_x_max);
    localparam int c_y_width = $clog2(p_y_max);
    localparam int c_sobel_comp_width = $clog2(4*(2**8)+2*(2**9));

    logic clk=1;
    logic rst=1;
    logic i_valid;
    logic [p_data_width-1:0] i_data;
    logic o_valid;
    logic [c_sobel_comp_width-1:0] o_data;

    sobel_filter 
    #(
    .p_x_max      (p_x_max),
    .p_y_max      (p_y_max),
    .p_data_width (p_data_width)
    )
    dut 
    (
    .i_clk   (clk),
    .i_rst   (rst),
    .i_valid (i_valid),
    .i_data  (i_data),
    .o_valid (o_valid),
    .o_data  (o_data)
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
        $dumpvars(0, tb_sobel_filter);
    end

    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task init_mems();
    begin
        logic [7:0] init_array [(1 << c_x_width)-1];
        // init_array = new[p_x_max];
        for(int i = 0; i< $size(init_array); i++) begin
            init_array[i] = {2{4'(15-i)}};
        end
        for(int i = 0; i< $size(dut.gen_buffers[0].inst_row_buffer.mem); i++) begin
            // dut.gen_buffers[0].inst_row_buffer.mem[i] = init_array[i];
            dut.gen_buffers[0].inst_row_buffer.mem[i] = 0;
            dut.gen_buffers[1].inst_row_buffer.mem[i] = init_array[i];
        end
    end
    endtask

    task setup(msg="");
    begin
        rst = 1;
        i_valid = 0;
        i_data = 0;
        init_mems();
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

    `UNIT_TEST("border check")
    #1ns;
    fork
    begin
        i_valid = 1;
        repeat (140) begin
            i_valid = 1;
            for(int i = 0; i<160; i++) begin
                i_valid = 1;
                i_data = {2{4'(15-i)}};
                wait_cycles(1);
                i_valid = 0;
                // `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
                `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
                wait_cycles(1);
                // `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
                `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
            end
            i_valid = 0;
            wait_cycles(10);
        end
            wait_cycles(10);
        i_valid = 1;
        repeat (10) begin
        for(int i = 0; i<16; i++) begin
            i_valid = 1;
            i_data = {2{4'(15-i)}};
            wait_cycles(1);
            i_valid = 0;
            `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
            wait_cycles(1);
            `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
        end
        end
            wait_cycles(1);
            `ASSERT(dut.s_mem_wr_valid[1]);
            wait_cycles(1);
            `ASSERT(dut.s_mem_wr_valid[1]);
            wait_cycles(1);
            `ASSERT(dut.s_mem_wr_valid[1]);
            wait_cycles(1);
            `ASSERT(~dut.s_mem_wr_valid[1]);
    end
    join
    `UNIT_TEST_END

    `UNIT_TEST("Sobel components")
    #1ns;
    fork
    begin
        // repeat (163) begin
        //     `WAIT(dut.s_r.valid_in);
        //     #1ns;
        //     if (s_r.x_counter > 3 & s_r.x_counter < (p_x_max + 1)) begin
        //
        //     end
        // end
    end
    begin
        i_valid = 1;
        repeat (10) begin
        for(int i = 0; i<16; i++) begin
            i_valid = 1;
            i_data = {2{4'(15-i)}};
            wait_cycles(1);
            i_valid = 0;
            // `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
            wait_cycles(1);
            // `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
        end
        end
        i_valid = 0;
            wait_cycles(10);
            wait_cycles(10);
        i_valid = 1;
        repeat (10) begin
        for(int i = 0; i<16; i++) begin
            i_valid = 1;
            i_data = {2{4'(15-i)}};
            wait_cycles(1);
            i_valid = 0;
            `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
            wait_cycles(1);
            `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
        end
        end
            wait_cycles(1);
            `ASSERT(dut.s_mem_wr_valid[1]);
            wait_cycles(1);
            `ASSERT(dut.s_mem_wr_valid[1]);
            wait_cycles(1);
            `ASSERT(dut.s_mem_wr_valid[1]);
            wait_cycles(1);
            `ASSERT(~dut.s_mem_wr_valid[1]);
    end
    join
    `UNIT_TEST_END
    `UNIT_TEST("Data streaming 2 cycle")
    #1ns;
    begin
        i_valid = 1;
        repeat (10) begin
        for(int i = 0; i<16; i++) begin
            i_valid = 1;
            i_data = {2{4'(15-i)}};
            wait_cycles(1);
            i_valid = 0;
            // `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
            wait_cycles(1);
            // `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
        end
        end
        i_valid = 0;
            wait_cycles(10);
            wait_cycles(10);
        i_valid = 1;
        repeat (10) begin
        for(int i = 0; i<16; i++) begin
            i_valid = 1;
            i_data = {2{4'(15-i)}};
            wait_cycles(1);
            i_valid = 0;
            `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
            wait_cycles(1);
            `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
        end
        end
            wait_cycles(1);
            `ASSERT(dut.s_mem_wr_valid[1]);
            wait_cycles(1);
            `ASSERT(dut.s_mem_wr_valid[1]);
            wait_cycles(1);
            `ASSERT(dut.s_mem_wr_valid[1]);
            wait_cycles(1);
            `ASSERT(~dut.s_mem_wr_valid[1]);
    end
    `UNIT_TEST_END

    `UNIT_TEST("Data streaming")
    #1ns;
    begin
        i_valid = 1;
        repeat (10) begin
        for(int i = 0; i<16; i++) begin
            i_data = {2{4'(15-i)}};
            wait_cycles(1);
            // `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
        end
        end
        i_valid = 0;
            wait_cycles(10);
            wait_cycles(10);
        i_valid = 1;
        repeat (10) begin
        for(int i = 0; i<16; i++) begin
            i_data = {2{4'(15-i)}};
            wait_cycles(1);
            `ASSERT(dut.d_mem0_buffer == dut.d_live_buffer);
            `ASSERT(dut.d_mem1_buffer == dut.d_live_buffer);
        end
        end
        i_valid = 0;
        wait_cycles(10);
    end


    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
