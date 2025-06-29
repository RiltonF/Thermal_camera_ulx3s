`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

// This module normalizes from a given range and min values to range 0..255
// The data to be normalized is read from a memory

module flat_field_correction #(
    parameter int DATAW = 16,
    parameter int MAX_ADDR = 32*24-1,
    parameter int SAMPLE_FRAMES = 1,
    localparam int ADDRW = $clog2(MAX_ADDR)

) (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_start,

    input  logic             i_wr_valid,
    input  logic [ADDRW-1:0] i_wr_addr,
    input  logic [DATAW-1:0] i_wr_data,

    input  logic             i_rd_valid,
    input  logic [ADDRW-1:0] i_rd_addr,
    output logic [DATAW-1:0] o_rd_data,

    output logic [7:0] o_debug,

    output logic signed [DATAW-1:0] o_frame_avg
);
    //Interface for the ffc memory
    logic             s_wr_valid;
    logic [ADDRW-1:0] s_wr_addr;
    logic [DATAW-1:0] s_wr_data;
    logic             s_rd_valid;
    logic [ADDRW-1:0] s_rd_addr;
    logic [DATAW-1:0] s_rd_data;

    //latched values
    logic             s_raw_valid;
    logic [ADDRW-1:0] s_raw_addr;
    logic [DATAW-1:0] s_raw_data;

    typedef enum {
        IDLE=0,
        WAIT_FRAME=1,
        LOAD_FRAME=2,
        CALC_PIXEL_AVG=3,
        CALC_FRAME_AVG=4
    } t_states;

    localparam int c_accumilator_width = DATAW+$clog2(MAX_ADDR);
    typedef struct packed {
        t_states state;
        logic [ADDRW-1:0] addr;
        logic [$clog2(SAMPLE_FRAMES):0] frame_count;
        logic [c_accumilator_width:0] pixel_sum;
        logic [c_accumilator_width*2-1:0] frame_avg; //large width because we don't want to truncate when doing multiplication of Q0.16
        // logic [ADDRW-1:0] addr;
    } t_signals;

    t_signals s_r, s_r_next;

    `ifndef SIMULATION
        localparam t_signals c_signals_reset =
            '{state:IDLE, default:'0};
    `else
        localparam t_signals c_signals_reset =
            {IDLE, '0};

        t_states d_state;
        logic [ADDRW-1:0] d_addr;
        logic [$clog2(SAMPLE_FRAMES):0] d_frame_count;
        logic [c_accumilator_width:0] d_pixel_sum;
        logic [c_accumilator_width*2-1:0] d_frame_avg; //large width because we don't want to truncate when doing multiplication of Q0.16
        assign d_state = t_states'(s_r.state);
        assign d_addr = s_r.addr;
        assign d_frame_count = s_r.frame_count;
        assign d_pixel_sum = s_r.pixel_sum;
        assign d_frame_avg = s_r.frame_avg;
    `endif

    //latch inputs no reset requred
    always_ff @(posedge i_clk) begin
        s_raw_valid <= i_wr_valid;
        s_raw_addr  <= i_wr_addr;
        s_raw_data  <= i_wr_data;
    end

    assign o_frame_avg = s_r.frame_avg; //truncate the upper bits since they should be 0

    assign o_debug = {s_r.state, i_start};

    always_comb begin
        s_r_next = s_r;

        s_wr_valid = (s_r.state == LOAD_FRAME) & s_raw_valid;
        s_wr_addr  = s_raw_addr;
        s_wr_data  = s_raw_data;


        // TODO: add multi frame sampling
        s_rd_valid = (s_r.state == IDLE) ? i_rd_valid : '0; //disable when not in idle mode
        s_rd_addr  = (s_r.state == IDLE) ? i_rd_addr  : '0;
        o_rd_data  = (s_r.state == IDLE) ? s_rd_data  : '0;

        case(s_r.state)
            IDLE: begin
                if (i_start) begin
                    s_r_next.state = WAIT_FRAME;
                    s_r_next.frame_count = '0;
                end
            end
            WAIT_FRAME: begin
                //We've captured all the frame samples, ffc calculation done
                if (s_r.frame_count >= SAMPLE_FRAMES) begin
                    s_r_next.state = IDLE;
                end
                //trigger on start of frame
                else if (i_wr_valid & (i_wr_addr == '0)) begin
                    s_r_next.state = LOAD_FRAME;
                    s_r_next.pixel_sum = '0;
                end
            end
            LOAD_FRAME: begin
                //Delay if not valid
                if (s_raw_valid) begin
                    //Accumilate the pixel sum to be used to calculate frame average
                    s_r_next.pixel_sum = s_r.pixel_sum + s_raw_data;

                    if (s_raw_addr >= MAX_ADDR) begin
                        s_r_next.state = CALC_FRAME_AVG;
                    end
                end
            end
            // TODO: add multi frame sampling
            // CALC_PIXEL_AVG: begin
            // end
            CALC_FRAME_AVG: begin
                // 1/(32*24) ~= 0.00130208
                // -> fixedpoint Q0.16 will result = 0.00130208 << 16 ~= 85.33 ~= 85
                // 85 is about 3.9e-3 % error, ~0.004%. I can live with that :)
                s_r_next.frame_avg = (s_r.pixel_sum * 8'd85) >> 16; //shift back to remove fractions
                s_r_next.frame_count++;
                s_r_next.state = WAIT_FRAME;
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

    mu_ram_1r1w #(
        .DW($bits(s_wr_data)),
        .AW($bits(s_wr_addr))
    ) inst_ffc_ram (
        .clk(i_clk),
        //Write interface
        .we     (s_wr_valid),
        .waddr  (s_wr_addr),
        .wr     (s_wr_data),
        //Read interface
        .re     (s_rd_valid),
        .raddr  (s_rd_addr),
        .rd     (s_rd_data)
    );
endmodule


