`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
module camera_read (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_vsync,
    input  logic i_href,
    input  logic [7:0] i_data,
    output logic o_valid,
    output logic [15:0] o_data,
    output logic o_frame_done,
    output logic [9:0] o_row,
    output logic [9:0] o_col,
    output logic [9:0] o_row_max,
    output logic [9:0] o_col_max
);

    typedef enum logic[1:0] {WAIT_FRAME_START=0, ROW_CAPTURE=1} t_states;
    t_states s_state;

    logic s_pixel_half;
    logic s_old_vsync;

    // NOTE: IDK why s_framestart didn't work instead of just i_vsync to go to
    // WAIT_FRAME_STATE, the output was always blank. I think synthesis was
    // optimizing it away, but it wasn't working for me at all. I tired with
    // attributes such ase (* keep *) but it didn't work. Also tried wire and
    // logic for the s_framestart, no difference. Yosys gave no warnings, at
    // least not one that I was able to figure out...

    always_ff @(posedge i_clk) s_old_vsync <= i_vsync;
    wire s_framestart = (s_old_vsync == 1'b0) & (i_vsync == 1'b1);

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_state <= WAIT_FRAME_START;
            o_valid <= '0;
            o_data <= '0;
            o_frame_done <= '0;
            o_row <= '0;
            o_col <= '0;
            o_row_max <= '0;
            o_col_max <= '0;
            s_pixel_half <= '0;
        end else begin
            //some debug:
            if (o_row > o_row_max) o_row_max <= o_row;
            if (o_col > o_col_max) begin
                o_col_max <= o_col;
            //     o_row_max <= o_row;
            end
            case (s_state)
                WAIT_FRAME_START: begin
                    // s_state <= t_states'((s_framestart) ? ROW_CAPTURE : WAIT_FRAME_START);
                    s_state <= t_states'((i_vsync) ? ROW_CAPTURE : WAIT_FRAME_START);

                    o_valid <= '0;
                    o_data <= '0;
                    o_frame_done <= '0;
                    o_row <= '0;
                    o_col <= '0;
                    s_pixel_half <= '0;
                end
                ROW_CAPTURE: begin
                    s_state <= t_states'((i_vsync) ? ROW_CAPTURE : WAIT_FRAME_START);
                    o_valid <= i_href & s_pixel_half;
                    o_col<= (o_valid) ? o_col + 1 : o_col;
                    if (i_href) begin
                        s_pixel_half <= ~s_pixel_half;
                        if (~s_pixel_half) begin
                            // o_data[7:0] <= '0; //remove to save power
                            o_data[15:8] <= i_data;
                        end else begin
                            o_data[7:0] <= i_data;
                        end
                    end else begin
                        s_pixel_half <= '0; //redundant?
                        o_col <= '0;
                        o_row<= (o_col > 0) ? o_row + 1'b1 : o_row;
                    end
                end
                default: s_state <= WAIT_FRAME_START;
            endcase
        end
    end
endmodule


