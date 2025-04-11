`default_nettype none 
// No native support for 3.3v hdmi differential so we fake it

module tb_serializer;

    logic clk = 0, rst = 1;
    logic [9:0] i_data;
    logic [1:0] o_data;
    logic [1:0] o_clk;

    always #5 clk = ~clk; // verilator lint_off STMTDLY

    serializer dut (
        .i_clk_shift(clk),
        .i_rst(rst),
        .i_data(i_data),
        .o_data(o_data),
        .o_clk(o_clk)
    );

    initial begin
        //setup waveform dump
        $dumpfile("wave.vcd");
        $dumpvars(0,tb_serializer);
        $dumpvars(0,dut);

        //init
        rst = 1;
        i_data = '0;
        wait_cycles(10);
        rst = 0;
        i_data = 'b1;
        // i_data = 'b1111000011;
        wait_cycles(3);
        // i_data = '1;
        wait_cycles(2);
        // i_data = 'b1000100001;
        wait_cycles(10);
        wait_cycles(10);
        i_data = '0;

        $finish;
    end

    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask
endmodule
