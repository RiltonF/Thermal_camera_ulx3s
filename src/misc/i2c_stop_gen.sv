`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module i2c_stop_gen #(
    parameter int CLK_FREQ = 25_000_000,
    parameter int I2C_FREQ = 100_000
) (
    input  logic i_clk,
    input  logic i_rst,

    input  logic i_enable,

    input  logic i_req,
    output logic o_done,
    output logic o_ready,

    input  logic i_sda,
    input  logic i_scl,

    output logic o_sda_drive,
    output logic o_scl_drive
);
    localparam int c_tansaction_time = CLK_FREQ / (4 * I2C_FREQ);

    typedef enum {
        IDLE=0, WAIT=1,
        CLK_UP=2, SDA_DOWN=3,
        SDA_UP=4, DONE=5
    } t_states;

    typedef struct packed {
        t_states state, state_return;
        logic sda;
        logic scl;
        logic [$clog2(c_tansaction_time)+3:0] timeout_counter;
    } t_control;

    t_control s_r, s_r_next;

    `ifndef SIMULATION
        localparam t_control c_control_reset = '{
            state: IDLE,
            state_return: IDLE,
            sda: 1'b1,
            scl: 1'b1,
            default: '0
        };
    `else
        //Iverilog doesn't support the construct above ^
        //It throws a synthax error
        localparam t_control c_control_reset = '{
            IDLE,
            IDLE,
            1'b1,
            1'b1,
            '0
        };

        //Iverilog also flattens structs mapping them directly is required for
        //context
        t_states d_state, d_state_return;
        logic d_sda;
        logic d_scl;
        logic [$clog2(c_tansaction_time)-1:0] d_timeout_counter;
        assign d_state = s_r.state;
        assign d_state_return= s_r.state_return;
        assign d_sda= s_r.sda;
        assign d_scl= s_r.scl;
        assign d_timeout_counter = s_r.timeout_counter;
    `endif

    //mask ready if clock is high
    assign o_ready = (s_r.state == IDLE) & (i_scl != 1'b1);
    assign o_done = (s_r.state == DONE);
    assign o_sda_drive = s_r.sda;
    assign o_scl_drive = s_r.scl;

    always_comb begin
        s_r_next = s_r; //init

        case (s_r.state)
            IDLE: begin
                if(i_enable) begin
                    //follow the current state of the line for smooth transition.
                    s_r_next.sda = i_sda;
                    s_r_next.scl = i_scl;
                    //accept request if scl is low
                    if (i_req & o_ready) begin
                        s_r_next.scl = 1'b0; //reset the scl to 0
                        s_r_next.state = SDA_DOWN;
                    end
                end
            end
            SDA_DOWN: begin
                s_r_next.state = WAIT;
                s_r_next.state_return = CLK_UP;
                s_r_next.timeout_counter = c_tansaction_time;
                s_r_next.sda = 1'b0;
            end
            CLK_UP: begin
                //Stall if the slave is clock stretching
                s_r_next.state = t_states'((i_scl == 1'b1) ? SDA_UP: WAIT);
                s_r_next.state_return = CLK_UP;
                s_r_next.timeout_counter = c_tansaction_time;
                s_r_next.scl = 1'b1;
            end
            SDA_UP: begin
                s_r_next.state = WAIT;
                s_r_next.state_return = DONE;
                // s_r_next.timeout_counter = c_tansaction_time << 3;
                s_r_next.timeout_counter = '1;
                s_r_next.sda = 1'b1;
            end
            DONE: begin
                s_r_next.state = IDLE;
            end
            WAIT: begin
                if (s_r.timeout_counter == '0) begin
                    s_r_next.state = s_r.state_return;
                end else begin
                    s_r_next.timeout_counter--;
                end
            end
            default: begin
                s_r_next.state = IDLE;
            end
        endcase
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_r <= c_control_reset;
        end else begin
            s_r <= s_r_next;
        end
    end
endmodule


