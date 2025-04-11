module dvi_gen #(
    parameter p_x_len = 800,
    parameter p_y_len = 525 
) (
    input i_clk,
    input i_rst
);
    localparam c_x_width = $clog2(p_x_len);
    localparam c_y_width = $clog2(p_y_len);

    typedef struct packed {
        logic [c_x_width-1:0] x_counter;
        logic [c_y_width-1:0] y_counter;
    } t_signals;

    localparam t_signals c_reset = '{default: 0};

    t_signals s_r, s_r_next; 

    always_comb begin
        //initial assignment
        s_r_next = s_r;

        s_r_next.x_counter = (s_r.x_counter >= p_x_len - 1) ? '0 : s_r.x_counter + 1'b1;
        s_r_next.y_counter = (s_r.y_counter >= p_y_len - 1) ? '0 : s_r.y_counter + 1'b1;

    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_r <= c_reset;
        end else begin
            s_r <= s_r_next;
        end
    end

endmodule


