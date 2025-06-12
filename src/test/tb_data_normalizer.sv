// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"
// Specify the module to load or on files.f
`include "data_normalizer.sv"
`include "divu_int.sv"
`timescale 1 ns / 100 ps

module tb_data_normalizer();

    `SVUT_SETUP

    parameter int DATAW = 16;
    parameter int MAX_ADDR = 20;
    parameter int FRACTIONW = 12;
    localparam int ADDRW = $clog2(MAX_ADDR);

    logic clk=1;
    logic rst=1;
    logic i_start;
    logic signed [DATAW-1:0] i_min;
    logic signed [DATAW-1:0] i_range;
    logic             o_rd_valid;
    logic [ADDRW-1:0] o_rd_addr;
    logic [DATAW-1:0] i_rd_data;
    logic             o_wr_valid;
    logic [ADDRW-1:0] o_wr_addr;
    logic [    8-1:0] o_wr_data;

    data_normalizer 
    #(
    .DATAW     (DATAW),
    .MAX_ADDR  (MAX_ADDR),
    .FRACTIONW (FRACTIONW)
    )
    dut 
    (
    .i_clk      (clk),
    .i_rst      (rst),
    .i_start    (i_start),
    .i_min      (i_min),
    .i_range    (i_range),
    .o_rd_valid (o_rd_valid),
    .o_rd_addr  (o_rd_addr),
    .i_rd_data  (i_rd_data),
    .o_wr_valid (o_wr_valid),
    .o_wr_addr  (o_wr_addr),
    .o_wr_data  (o_wr_data)
    );

    typedef enum {
        IDLE=0,
        SCALE_CALC=1,
        PIXEL_READ=2
    } t_states;
    // alias t_states = dut.t_signals;

    localparam int c_div_width = $clog2(255) + FRACTIONW;
    t_states d_state;
    logic [ADDRW-1:0] d_addr;
    logic d_div_start;
    logic signed [DATAW-1:0] d_min;
    logic signed [DATAW-1:0] d_range;
    logic [c_div_width-1:0] d_scale_value;

    assign d_state = t_states'(dut.s_r.state);
    assign d_addr = dut.s_r.addr;
    assign d_div_start = dut.s_r.div_start;
    assign d_min = dut.s_r.min;
    assign d_range = dut.s_r.range;
    assign d_scale_value = dut.s_r.scale_value;


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
        // $dumpvars(0, tb_data_normalizer);
        $dumpvars;
    end
    // Setup time format when printing with $realtime()
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        rst = 1;
        i_min = '0;
        i_range = '0;
        i_start = '0;
        i_rd_data = '0;
        wait_cycles(8);
        rst = 0;
        wait_cycles(8);
    end
    endtask

    task teardown(msg="");
    begin
        rst = 1;
        wait_cycles(8);
    end
    endtask

    `TEST_SUITE("TESTSUITE_NAME")


    `UNIT_TEST("TEST_MIN_-5")
        #1ns;
        fork
        begin
            repeat (MAX_ADDR) begin
                `WAIT(o_wr_valid)
                #2ns;
                $display((dut.s_r.scale_value * o_wr_addr)>>FRACTIONW);
                `ASSERT(o_wr_data == (dut.s_r.scale_value * o_wr_addr)>>FRACTIONW)
                wait_cycles(1);
            end
        end
        begin
            i_start = 1;
            i_min = -5;
            i_range = MAX_ADDR;
            `WAIT(dut.inst_slow_divider.done)
            i_rd_data = -5;
            wait_cycles(1);
            repeat (i_range) begin
                wait_cycles(1);
                i_rd_data++;
            end
            wait_cycles(10);
        end
        join_any
        disable fork;

    `UNIT_TEST_END
    `UNIT_TEST("TEST_MAX_clipping")
        #1ns;
        fork
        begin
            repeat (MAX_ADDR) begin
                `WAIT(o_wr_valid & dut.s_pixel_normalized > 255)
                #2ns;
                $display(dut.s_pixel_normalized);
                `ASSERT(o_wr_data == 255)
                wait_cycles(1);
            end
        end
        begin
            i_start = 1;
            i_min = -5;
            i_range = MAX_ADDR;
            `WAIT(dut.inst_slow_divider.done)
            i_rd_data = 0;
            wait_cycles(1);
            repeat (i_range) begin
                wait_cycles(1);
                i_rd_data++;
            end
            wait_cycles(10);
        end
        join_any
        disable fork;

    `UNIT_TEST_END
    `UNIT_TEST("TEST_MIN_0")
        #1ns;
        fork
        begin
            repeat (MAX_ADDR) begin
                `WAIT(o_wr_valid)
                #2ns;
                $display((dut.s_r.scale_value * o_wr_addr)>>FRACTIONW);
                `ASSERT(o_wr_data == (dut.s_r.scale_value * o_wr_addr)>>FRACTIONW)
                wait_cycles(1);
            end
        end
        begin
            i_start = 1;
            i_range = MAX_ADDR;
            `WAIT(dut.inst_slow_divider.done)
            i_rd_data = 0;
            wait_cycles(1);
            repeat (i_range) begin
                wait_cycles(1);
                i_rd_data++;
            end
            wait_cycles(10);
        end
        join_any
        disable fork;

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
