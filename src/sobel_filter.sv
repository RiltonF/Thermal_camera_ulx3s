`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module sobel_filter #(
    parameter int p_x_max = 160,
    parameter int p_y_max = 120,
    parameter int p_data_width = 8,
    localparam int c_x_width = $clog2(p_x_max),
    localparam int c_y_width = $clog2(p_y_max),
    localparam int c_sobel_comp_width = $clog2(4*(2**8)+2*(2**9))
) (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_valid,
    input  logic [p_data_width-1:0] i_data,
    output logic o_valid,
    output logic [c_sobel_comp_width-1:0] o_data
);
    //Memory interface signals
    logic                    s_mem_rd_valid [2];
    logic [   c_x_width-1:0] s_mem_rd_addr  [2];
    logic [p_data_width-1:0] s_mem_rd_data  [2];
    logic                    s_mem_wr_valid [2];
    logic [   c_x_width-1:0] s_mem_wr_addr  [2];
    logic [p_data_width-1:0] s_mem_wr_data  [2];

    //icarus verilog sim doesn't support upacked arrays...
    //and flattens all arrays in the wave dump
    typedef struct packed {
        logic active_buffer;
        logic valid_in;
        logic [p_data_width-1:0] data_in;
        logic [1:0][2:0][p_data_width-1:0] mem_buffer;
        logic [2:0][p_data_width-1:0] live_buffer;
        logic [c_x_width:0] x_counter;
        logic [c_y_width:0] y_counter;
        logic signed [c_sobel_comp_width-1:0] x_comp;
        logic signed [c_sobel_comp_width-1:0] y_comp;
        logic comp_valid;
        logic unsigned [c_sobel_comp_width-1:0] sobel_mag;
        logic mag_valid;
    }t_signals;

    t_signals s_r, s_r_next;

    `ifndef SIMULATION
        localparam t_signals c_reset = '{default: '0};
    `else
        localparam t_signals c_reset = {'0,'0,'0,'0,'0,'0,'0,'0};
        logic d_active_buffer;
        logic d_valid_in;
        logic [p_data_width-1:0] d_data_in;
        logic [1:0][2:0][p_data_width-1:0] d_mem_buffer;
        logic [2:0][p_data_width-1:0] d_mem0_buffer;
        logic [2:0][p_data_width-1:0] d_mem1_buffer;
        logic [2:0][p_data_width-1:0] d_live_buffer;
        logic [c_x_width:0] d_x_counter;
        logic [c_y_width:0] d_y_counter;
        logic signed [c_sobel_comp_width-1:0] d_x_comp;
        logic signed [c_sobel_comp_width-1:0] d_y_comp;
        logic d_comp_valid;
        assign d_active_buffer = s_r.active_buffer;
        assign d_valid_in = s_r.valid_in;
        assign d_data_in = s_r.data_in;
        assign d_mem_buffer = s_r.mem_buffer;
        assign d_mem0_buffer = s_r.mem_buffer[0];
        assign d_mem1_buffer = s_r.mem_buffer[1];
        assign d_live_buffer = s_r.live_buffer;
        assign d_x_counter = s_r.x_counter;
        assign d_y_counter = s_r.y_counter;
        assign d_x_comp = s_r.x_comp;
        assign d_y_comp = s_r.y_comp;
        assign d_comp_valid = s_r.comp_valid;
    `endif

    //Buffer memory write assignments
    assign s_mem_wr_data[0] = s_r.live_buffer[2];
    assign s_mem_wr_data[1] = s_r.live_buffer[2];
    assign s_mem_wr_valid[0] = ~s_r.active_buffer & s_r.valid_in & s_r.x_counter > 'd3;
    assign s_mem_wr_valid[1] = s_r.active_buffer & s_r.valid_in & s_r.x_counter > 'd3;
    assign s_mem_wr_addr[0] = s_r.x_counter - 'd4;
    assign s_mem_wr_addr[1] = s_r.x_counter - 'd4;

    //Buffer memory read assignments
    // assign s_mem_rd_valid[0] = s_r.valid_in;
    // assign s_mem_rd_valid[1] = s_r.valid_in;
    assign s_mem_rd_valid[0] = i_valid;
    assign s_mem_rd_valid[1] = i_valid;
    assign s_mem_rd_addr[0] = s_r.x_counter;
    assign s_mem_rd_addr[1] = s_r.x_counter;

    assign o_valid = s_r.mag_valid;
    assign o_data = s_r.sobel_mag;
    always_comb begin
        s_r_next = s_r;

        //Counter state management
        s_r_next.data_in = i_data;
        if (s_r.x_counter < p_x_max) begin
            s_r_next.valid_in = i_valid;
            if (i_valid) s_r_next.x_counter++;
        end else if (s_r.x_counter < (p_x_max + 3)) begin
            assert(i_valid == 1'b0);
            s_r_next.valid_in = 1'b1;
            s_r_next.x_counter++;
        end else begin
            s_r_next.y_counter++; //increment the y_counter
            s_r_next.valid_in = 1'b0;
            s_r_next.x_counter = '0;
            s_r_next.active_buffer = ~s_r.active_buffer; //switch buffers
        end

        //Window 3x3 management
        if (s_r.valid_in) begin
            s_r_next.mem_buffer[0] = {s_r.mem_buffer[0][1:0], s_mem_rd_data[0]};
            s_r_next.mem_buffer[1] = {s_r.mem_buffer[1][1:0], s_mem_rd_data[1]};
            s_r_next.live_buffer = {s_r.live_buffer[1:0], s_r.data_in};
        end

        //sobel filter
        //Valid window starts at index 3
        s_r_next.comp_valid = s_r.valid_in & s_r.x_counter > 2 & s_r.x_counter < (p_x_max + 3);
        // Need minimum of 3 samples, x_counter runs one cycle faster so > 3,
        // Max is the p_x_max, and + 1 since the counter runs one cycle faster ^
        // Ignore the first and last rows 0 < y_counter < 159
        if (s_r.x_counter > 3 & s_r.x_counter < (p_x_max + 2) &
            s_r.y_counter > 0 & s_r.y_counter < (p_y_max - 2)) begin
            //Compute filter
            if (s_r.valid_in) begin
                //Have to use constants for 2D vectors because iverilog
                //doesn't support it otherwise
                if (s_r.active_buffer) begin
                    s_r_next.x_comp = -$signed(s_r.mem_buffer[1][2])
                                      +$signed(s_r.mem_buffer[1][0])
                                      -$signed(s_r.mem_buffer[0][2]<<1) //*2
                                      +$signed(s_r.mem_buffer[0][0]<<1) //*2
                                      -$signed(s_r.live_buffer[2])
                                      +$signed(s_r.live_buffer[0]);
                    s_r_next.y_comp = -$signed(s_r.mem_buffer[1][2])
                                      -$signed(s_r.mem_buffer[1][1]<<1)
                                      -$signed(s_r.mem_buffer[1][0])
                                      +$signed(s_r.live_buffer[2])
                                      +$signed(s_r.live_buffer[1]<<1)
                                      +$signed(s_r.live_buffer[0]);
                end else begin
                    s_r_next.x_comp = -$signed(s_r.mem_buffer[0][2])
                                      +$signed(s_r.mem_buffer[0][0])
                                      -$signed(s_r.mem_buffer[1][2]<<1) //*2
                                      +$signed(s_r.mem_buffer[1][0]<<1) //*2
                                      -$signed(s_r.live_buffer[2])
                                      +$signed(s_r.live_buffer[0]);
                    s_r_next.y_comp = -$signed(s_r.mem_buffer[0][2])
                                      -$signed(s_r.mem_buffer[0][1]<<1)
                                      -$signed(s_r.mem_buffer[0][0])
                                      +$signed(s_r.live_buffer[2])
                                      +$signed(s_r.live_buffer[1]<<1)
                                      +$signed(s_r.live_buffer[0]);
                end
            end
        end else begin
            //We ignore the border pixels to avoid padding
            s_r_next.x_comp = '0;
            s_r_next.y_comp = '0;
        end
        //final sobbel step
        s_r_next.mag_valid = s_r.comp_valid;
        if (s_r.comp_valid) begin
            // mag = abs(x_comp) + abs(y_comp)
            // msb is the sign bit
            s_r_next.sobel_mag = 
                ((s_r.x_comp[c_sobel_comp_width-1]) ? -s_r.x_comp : s_r.x_comp) +
                ((s_r.y_comp[c_sobel_comp_width-1]) ? -s_r.y_comp : s_r.y_comp);
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_r <= c_reset;
        end else begin
            s_r <= s_r_next;
        end
    end



    generate
    for(genvar i = 0; i < 2; i++) begin : gen_buffers
        mu_ram_1r1w #(
            .DW($bits(i_data)),
            .AW(c_x_width)
        ) inst_row_buffer (
            .clk(i_clk),
            //Read interface
            .re(s_mem_rd_valid[i]),
            .raddr(s_mem_rd_addr[i]),
            .rd(s_mem_rd_data[i]),
            //Write interface
            .we(s_mem_wr_valid[i]),
            .waddr(s_mem_wr_addr[i]),
            .wr(s_mem_wr_data[i])
        );
    end
    endgenerate

endmodule


