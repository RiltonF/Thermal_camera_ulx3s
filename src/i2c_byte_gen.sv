`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module i2c_byte_gen #(
    parameter int CLK_FREQ = 25_000_000,
    parameter int I2C_FREQ = 100_000
) (
    input  logic i_clk,
    input  logic i_rst,

    input  logic i_req,
    input  logic i_we,
    input  logic [7:0] i_wr_byte,
    input  logic i_rd_last, //used to send a nack when finished reading
    output logic o_ready,

    output logic o_wr_ack,
    output logic o_wr_nack,
    output logic o_rd_valid,
    output logic [7:0] o_rd_byte,

    //interface to bit gen *_bit
    output  logic o_req_bit,
    output  logic o_we_bit,
    output  logic o_wr_bit,
    input logic i_ready_bit,

    input logic i_rd_valid_bit,
    input logic i_rd_bit
);

    localparam int c_tansaction_time = CLK_FREQ / (4 * I2C_FREQ);
    typedef enum {
        IDLE=0, BIT_LOAD=1,
        BIT_REQ=2, WAIT_REQ=3,
        ACK_REQ=4
    } t_states;

    typedef struct packed {
        t_states state;
        logic write_en;
        logic rd_last;
        logic [7:0] req_byte;
        logic [$clog2(9)-1:0] bit_counter;
        logic rd_bit;
    } t_control;

    t_control s_r, s_r_next;

    `ifndef SIMULATION
        localparam t_control c_control_reset = '{
            state: IDLE,
            default: '0
        };
    `else
        //Iverilog doesn't support the construct above ^
        //It throws a synthax error
        localparam t_control c_control_reset = '{ IDLE, '0, '0, '0, '0, '0 };

        //Iverilog also flattens structs, mapping them directly is required for
        //context
        t_states d_state;
        logic d_write_en;
        logic [7:0] d_req_byte;
        logic [$clog2(9)-1:0] d_bit_counter;
        logic d_rd_bit;
        logic d_rd_last;
        assign d_state = s_r.state;
        assign d_write_en = s_r.write_en;
        assign d_req_byte = s_r.req_byte;
        assign d_bit_counter = s_r.bit_counter;
        assign d_rd_bit = s_r.rd_bit;
        assign d_rd_last = s_r.rd_last;
    `endif

    //mask ready if req bit is not available, this shouldn't happen
    assign o_ready = (s_r.state == IDLE) & i_ready_bit;

    //set ack high when 0 is read
    assign o_wr_ack = (s_r.state == ACK_REQ) & s_r.write_en & ~s_r.rd_bit;
    assign o_wr_nack = (s_r.state == ACK_REQ) & s_r.write_en & s_r.rd_bit;
    assign o_rd_valid = (s_r.state == ACK_REQ) & ~s_r.write_en;
    assign o_rd_byte = s_r.req_byte;

    assign o_req_bit = (s_r.state == BIT_REQ);
    //xnor the byte counter and write_en, so opposite operation for acks
    assign o_we_bit = (s_r.bit_counter < 'd8) ~^ s_r.write_en;
    //if sending ACK/NACK bit, (when reading req),
    //if last read, send a NACK to end the transaction
    assign o_wr_bit = (s_r.bit_counter < 'd8) ? s_r.req_byte[7] : s_r.rd_last;

    always_comb begin
        s_r_next = s_r; //init

        case (s_r.state)
            IDLE: begin
                //have a request and bit gen is ready
                if (i_req & i_ready_bit) begin
                    s_r_next.state = BIT_REQ;
                    s_r_next.rd_last = i_rd_last;
                    s_r_next.write_en = i_we;
                    s_r_next.req_byte = (i_we) ? i_wr_byte : '0;
                    s_r_next.bit_counter = '0;
                    s_r_next.rd_bit = '0;
                end
            end
            BIT_REQ: begin
                s_r_next.state = WAIT_REQ;
                //set timout counter here?
            end
            WAIT_REQ: begin
                //capture the read data
                if (i_rd_valid_bit) begin
                    s_r_next.rd_bit = i_rd_bit;
                end
                //wait until request finishes
                else if (i_ready_bit) begin
                    s_r_next.state = BIT_LOAD;
                end
            end
            BIT_LOAD: begin
                s_r_next.bit_counter = s_r_next.bit_counter + 1'b1;
                if (s_r.bit_counter < 'd8) begin
                    s_r_next.req_byte = {s_r.req_byte[6:0], s_r.rd_bit};
                    s_r_next.state = BIT_REQ;
                end else begin
                    s_r_next.state = ACK_REQ;
                end
            end
            //send out wr_ack or rd valid
            ACK_REQ: begin
                s_r_next.state = IDLE;
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


