`default_nettype none 
/* verilator lint_off WIDTHEXPAND */
// No native support for 3.3v hdmi differential so we fake it

module serializer #(
    parameter c_data_width = 10,
    parameter bit c_ddr_mode = 1 
)(
    input  logic i_clk_shift,
    input  logic i_rst,
    input  logic [c_data_width-1:0] i_data,
    output logic [1:0] o_data, //for Single Data Rate, you just use [0]
    output logic [1:0] o_clk //for Single Data Rate, you just use [0]
);
    logic [c_data_width-1:0] s_clk_out, s_data_shift;

    localparam c_init_count = {{(c_data_width/2){1'b0}}, {(c_data_width/2){1'b1}}};


    assign o_data = s_data_shift [1:0];
    assign o_clk = s_clk_out [1:0];

    always_ff @(posedge i_clk_shift) begin
        if (i_rst) begin
            s_clk_out <= c_init_count;
            s_data_shift <= '0;
        end else begin
            if (c_ddr_mode) begin
                //shift to the right by two, ring buffer style
                s_clk_out <= {s_clk_out[1:0], s_clk_out[c_data_width-1:2]};
            end else begin
                //shift to the right by one, ring buffer style
                s_clk_out <= {s_clk_out[0], s_clk_out[c_data_width-1:1]};
            end

            if (s_clk_out == c_init_count) begin
                s_data_shift <= i_data;
            end else begin
                if (c_ddr_mode) begin
                    //shift to the right by two, ring buffer style
                    s_data_shift <= {s_data_shift[1:0], s_data_shift[c_data_width-1:2]};
                end else begin
                    //shift to the right by one, ring buffer style
                    s_data_shift <= {s_data_shift[0], s_data_shift[c_data_width-1:1]};
                end
            end
        end
    end
endmodule


