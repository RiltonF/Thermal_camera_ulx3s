module blinky(
    input i_clk,
    input [6:0] i_btn,
    output [7:0] o_led
);

    localparam ctr_width = 32;
    logic [ctr_width-1:0] s_count = 0;

    always_comb begin
        for(int i=0; i<$bits(o_led)-1; i++) begin
            o_led[i] <= s_count[ctr_width-1-i];
        end
        o_led[7] <= i_btn[0];
    end
    always_ff @(posedge i_clk) begin
        s_count <= s_count + 1;
    end

endmodule


