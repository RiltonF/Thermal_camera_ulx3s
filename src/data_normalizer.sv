`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

// This module normalizes from a given range and min values to range 0..255
// The data to be normalized is read from a memory

module data_normalizer #(
    parameter int DATAW = 16,
    parameter int MAX_ADDR = 2**6-1,
    parameter int MULTIW = 18, //Max width of your dsp multiplier, ECP5 is 18
    parameter int FRACTIONW = 12, //This should be equal to or less than MULTIW
    localparam int ADDRW = $clog2(MAX_ADDR)

) (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_start,
    input  logic signed [DATAW-1:0] i_min,
    input  logic unsigned [DATAW-1:0] i_range,

    output logic             o_rd_valid,
    output logic [ADDRW-1:0] o_rd_addr,
    input  logic [DATAW-1:0] i_rd_data,

    output logic             o_wr_valid,
    output logic [ADDRW-1:0] o_wr_addr,
    output logic [    8-1:0] o_wr_data

);
    localparam int c_div_width = $clog2(255) + FRACTIONW;
    localparam [c_div_width-1:0] c_numerator = 255 << FRACTIONW;

    logic s_div_done;
    logic s_div_busy;
    logic s_div_valid;
    logic [c_div_width-1:0] s_div_result;

    typedef enum {
        IDLE=0,
        SCALE_CALC=1,
        PIXEL_READ=2
    } t_states;

    typedef struct packed {
        t_states state;
        logic [ADDRW-1:0] addr;
        logic div_start;
        logic signed [DATAW-1:0] min;
        logic unsigned [DATAW-1:0] range;
        logic [c_div_width-1:0] scale_value;
    } t_signals;

    t_signals s_r, s_r_next;

    `ifndef SIMULATION
        localparam t_signals c_signals_reset =
            '{state:IDLE, default:'0};
    `else
        localparam t_signals c_signals_reset =
            {IDLE, '0};
    `endif

    //Used for the scale computation (255<<FRACTIONW)/range
    divu_int #(
        .WIDTH(c_div_width)
    ) inst_slow_divider (
        .clk(i_clk),
        .rst(i_rst),
        .start(s_r.div_start),
        .busy(s_div_busy),
        .done(s_div_done),
        .valid(s_div_valid),
        .a(c_numerator),
        .b(s_r.range),
        .val(s_div_result)
    );

    localparam int c_pipe_len = 2;
    logic [c_pipe_len-1:0] s_pixel_valid;
    logic unsigned [MULTIW-1:0] s_pixel_delta;
    logic unsigned [MULTIW*2-1:0] s_pixel_multi;
    logic unsigned [MULTIW*2-FRACTIONW-1:0] s_pixel_normalized;

    assign o_rd_valid = (s_r.state == PIXEL_READ) & (s_r.addr < MAX_ADDR);
    assign o_rd_addr = s_r.addr;

    //Clip if values above 255
    assign o_wr_data = (s_pixel_normalized>>8 != '0) ? '1 : s_pixel_normalized;
    assign o_wr_addr = s_r.addr-2;
    assign o_wr_valid = s_pixel_valid[c_pipe_len-1];

    // Normalization pipeline
    assign s_pixel_normalized = s_pixel_multi >> FRACTIONW;
    always_ff @(posedge i_clk) begin
        s_pixel_valid <= {s_pixel_valid, o_rd_valid};
        s_pixel_delta <= $signed(i_rd_data) - $signed(s_r.min);
        // s_pixel_delta <= ($signed(i_rd_data) - $signed(s_r.min) > s_r.range) ? s_r.range : $signed(i_rd_data) - $signed(s_r.min);
        s_pixel_multi <= s_pixel_delta * s_r.scale_value;
    end

    always_comb begin
        s_r_next = s_r;
        case(s_r.state)
            IDLE: begin
                if (i_start) begin
                    s_r_next.state = SCALE_CALC;
                    s_r_next.div_start = 1'b1;
                    // Store the range an min values
                    // Check if range is zero, to prevent divide by 0
                    // TODO: ADD check for ranges that are too small
                    s_r_next.range = (|i_range) ? i_range : 1'b1;
                    s_r_next.min = i_min;
                end
            end
            SCALE_CALC: begin
                if (s_div_busy) begin
                    s_r_next.div_start = 1'b0;
                end else if (s_div_done & s_div_valid) begin
                    // Division is done
                    s_r_next.state = PIXEL_READ;
                    s_r_next.scale_value = s_div_result;
                    s_r_next.addr = '0;
                end
            end
            PIXEL_READ: begin
                if (s_r.addr >= MAX_ADDR + c_pipe_len) begin
                    s_r_next.state = IDLE;
                end else begin
                    s_r_next.addr++;
                end
            end
            default: begin
                s_r_next = c_signals_reset;
            end
        endcase
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_r <= c_signals_reset;
        end else begin
            s_r <= s_r_next;
        end
    end
endmodule


