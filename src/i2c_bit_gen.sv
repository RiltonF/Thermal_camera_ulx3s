`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module i2c_bit_gen #(
    parameter int CLK_FREQ = 25_000_000,
    parameter int I2C_FREQ = 100_000
) (
    input  logic i_clk,
    input  logic i_rst,

    input  logic i_req,
    input  logic i_we,
    input  logic i_wr_bit,
    output logic o_ready,

    output logic o_rd_valid,
    output logic o_rd_bit,

    input  logic i_sda,
    input  logic i_scl,

    output logic o_sda_drive,
    output logic o_scl_drive

    // inout  logic b_sda, //bidirectonal
    // inout  logic b_scl
);
    localparam int c_tansaction_time = CLK_FREQ / (4 * I2C_FREQ);

    typedef enum {
        IDLE=0, WAIT=1,
        CLK_UP=2, CLK_DOWN=3,
        BIT_WRITE=4, BIT_READ=5
    } t_states;

    typedef struct packed {
        t_states state, state_return;
        logic write_en;
        logic rd_bit;
        logic wr_bit;
        logic sda;
        logic scl;
        logic [$clog2(c_tansaction_time)-1:0] timeout_counter;
    } t_control;

    t_control s_r, s_r_next;

    `ifndef SIMULATION
        localparam t_control c_control_reset = '{
            state: IDLE,
            state_return: IDLE,
            sda: 1'b0,
            scl: 1'b0,
            default: '0
        };
    `else
        //Iverilog doesn't support the construct above ^
        //It throws a synthax error
        localparam t_control c_control_reset = '{
            IDLE,
            IDLE,
            1'b0,
            1'b0,
            1'b0,
            1'b0,
            1'b0,
            '0
        };

        //Iverilog also flattens structs mapping them directly is required for
        //context
        t_states d_state, d_state_return;
        logic d_write_en;
        logic d_rd_bit;
        logic d_wr_bit;
        logic d_sda;
        logic d_scl;
        logic [$clog2(c_tansaction_time)-1:0] d_timeout_counter;
        assign d_state = s_r.state;
        assign d_state_return= s_r.state_return;
        assign d_write_en= s_r.write_en;
        assign d_rd_bit= s_r.rd_bit;
        assign d_wr_bit= s_r.wr_bit;
        assign d_sda= s_r.sda;
        assign d_scl= s_r.scl;
        assign d_timeout_counter = s_r.timeout_counter;
    `endif

    //I2C assignments
    // assign b_sda = (s_r.sda) ? 1'bz : 1'b0; //required for in/out buffers
    // assign b_scl = (s_r.scl) ? 1'bz : 1'b0;

    //maks ready if clock is high
    assign o_ready = (s_r.state == IDLE) & (i_scl != 1'b1);
    assign o_rd_valid = (s_r.state == CLK_DOWN) & ~s_r.write_en;
    assign o_rd_bit = s_r.rd_bit;
    assign o_sda_drive = s_r.sda;
    assign o_scl_drive = s_r.scl;

    always_comb begin
        s_r_next = s_r; //init

        case (s_r.state)
            IDLE: begin
                s_r_next.scl = 1'b0;
                //accept request if scl is low
                if (i_req & o_ready) begin
                    s_r_next.state = BIT_WRITE;
                    s_r_next.write_en = i_we;
                    s_r_next.wr_bit = i_wr_bit;
                end
            end
            BIT_WRITE: begin
                s_r_next.state = WAIT;
                s_r_next.state_return = CLK_UP;
                s_r_next.timeout_counter = c_tansaction_time;
                //write data if we is enabled, else leave high
                s_r_next.sda = (s_r.write_en) ? s_r.wr_bit : 1'b1;
            end
            CLK_UP: begin
                //Stall if the slave is clock stretching
                s_r_next.state = t_states'((i_scl == 1'b1) ? BIT_READ : WAIT);
                s_r_next.state_return = CLK_UP;
                s_r_next.timeout_counter = c_tansaction_time;
                s_r_next.scl = 1'b1;
            end
            BIT_READ: begin // NOTE: idk if wait is required
                s_r_next.state = WAIT;
                s_r_next.state_return = CLK_DOWN;
                s_r_next.timeout_counter = c_tansaction_time;
                s_r_next.rd_bit = (s_r.write_en) ? 1'b0 : i_sda;
            end
            CLK_DOWN: begin
                s_r_next.state = WAIT;
                s_r_next.state_return = IDLE;
                s_r_next.timeout_counter = c_tansaction_time;
                s_r_next.scl = 1'b0;
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


