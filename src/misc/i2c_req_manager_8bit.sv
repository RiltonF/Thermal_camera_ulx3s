`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

import package_i2c::t_gen_states;
import package_i2c::NONE;
import package_i2c::START;
import package_i2c::BYTE;
import package_i2c::STOP;

module i2c_req_manager_8bit #(
    parameter int BURST_WIDTH = 4
) (
    input  logic i_clk,
    input  logic i_rst,

    //I2C master enable
    input  logic i_enable,

    //From CMD FIFO
    input  logic i_valid,
    input  logic i_we,
    input  logic i_sccb_mode,
    input  logic [6:0] i_addr_slave,
    input  logic [7:0] i_addr_reg,
    input  logic [BURST_WIDTH-1:0] i_burst_num,
    output logic o_ready,

    //From WR Byte FIFO
    input  logic i_valid_wr_byte,
    input  logic [7:0] i_wr_byte,
    output logic o_ready_wr_byte,

    //From RD Byte FIFO
    input logic i_ready_rd_byte,

    //Output to byte_gen module
    output logic [7:0] o_wr_byte,

    //Input from byte_gen module
    input logic i_byte_ready,
    input logic i_wr_ack,
    input logic i_wr_nack,
    input logic i_rd_valid,

    //Input OR-reduced from start/stop gen
    input logic i_start_ready,
    input logic i_start_done,

    input logic i_stop_ready,
    input logic i_stop_done,

    //[None=0,Start=1,Byte=2,Stop=3]
    output t_gen_states o_active_gen,
    output t_gen_states o_active_gen_next,
    // output logic        o_req_enable,
    //
    output logic        o_req_valid,
    output logic        o_req_we,
    output logic        o_req_last_byte
);

    typedef enum {
        IDLE=0, REQ_LOAD=1,
        REQ_CONTROL=2, INIT_GEN=3,
        REQ_GEN=4, WAIT_GEN=5, END_GEN=6
    } t_states;

    typedef struct packed {
        t_states state;
        t_gen_states active_gen;
        t_gen_states active_gen_next;
        logic write_en;
        logic sccb_mode;
        logic wr_ack;
        logic [6:0] addr_slave;
        logic [7:0] addr_reg;
        logic [7:0] req_byte;
        logic [BURST_WIDTH-1:0] burst_num;
        logic [BURST_WIDTH-1:0] byte_counter;
        logic last_byte;
    } t_control;

    t_control s_r, s_r_next;

    `ifndef SIMULATION
        localparam t_control c_control_reset = '{
            state: IDLE,
            active_gen: NONE,
            active_gen_next: NONE,
            default: '0
        };
    `else
        //Iverilog doesn't support the construct above ^
        //It throws a synthax error
        localparam t_control c_control_reset = '{
            IDLE, NONE, NONE, '0, '0, '0, '0, '0, '0, '0, '0, '0};

        //Iverilog also flattens structs, mapping them directly is required for
        //context
        t_states d_state;
        t_gen_states d_active_gen;
        t_gen_states d_active_gen_next;
        logic d_write_en;
        logic d_sccb_mode;
        logic d_wr_ack;
        logic [6:0] d_addr_slave;
        logic [7:0] d_addr_reg;
        logic [7:0] d_req_byte;
        logic [BURST_WIDTH-1:0] d_burst_num;
        logic [BURST_WIDTH-1:0] d_byte_counter;
        logic d_last_byte;
        assign d_state = s_r.state;
        assign d_active_gen = s_r.active_gen;
        assign d_active_gen_next = s_r.active_gen_next;
        assign d_write_en = s_r.write_en;
        assign d_sccb_mode = s_r.sccb_mode;
        assign d_wr_ack = s_r.wr_ack;
        assign d_addr_slave = s_r.addr_slave;
        assign d_addr_reg = s_r.addr_reg;
        assign d_req_byte = s_r.req_byte;
        assign d_burst_num = s_r.burst_num;
        assign d_byte_counter = s_r.byte_counter;
        assign d_last_byte = s_r.last_byte;
    `endif

    //mask ready if START is not available
    assign o_ready = (s_r.state == REQ_LOAD) & i_start_ready;

    assign o_wr_byte = s_r.req_byte;

    assign o_active_gen = s_r.active_gen;
    assign o_active_gen_next = s_r.active_gen_next;
    assign o_req_valid = (s_r.state == REQ_GEN);
    assign o_req_last_byte = s_r.last_byte;
    //first two bytes are writes, slave addr and reg addr
    assign o_req_we =
        (s_r.byte_counter >= 3) ? s_r.write_en : 1'b1;
    //pop the read data
    assign o_ready_wr_byte = (s_r.state == REQ_GEN)
                           & (s_r.byte_counter >= 'd2)
                           & (s_r.active_gen == BYTE)
                           & (s_r.write_en);

    always_comb begin
        s_r_next = s_r; //init

        case (s_r.state)
            IDLE: begin
                s_r_next.state = t_states'((i_enable) ? REQ_LOAD : IDLE);
                s_r_next.active_gen = NONE;
            end
            REQ_LOAD: begin
                //Load all the requred data for the request
                if (i_valid & o_ready) begin
                    s_r_next.state = REQ_CONTROL;
                    s_r_next.write_en = i_we;
                    s_r_next.sccb_mode = i_sccb_mode;
                    s_r_next.addr_slave = i_addr_slave;
                    s_r_next.addr_reg = i_addr_reg;
                    s_r_next.wr_ack = '0;
                    //Set to 0 if in sscb mode, no bursts allowed
                    s_r_next.burst_num = (i_sccb_mode) ? '0 : i_burst_num;
                    s_r_next.byte_counter = '0;
                    s_r_next.last_byte = '0;
                    s_r_next.active_gen_next = START;
                end else begin
                    s_r_next.state = REQ_LOAD;
                end
            end
            REQ_CONTROL: begin
                case (s_r.active_gen_next)
                    NONE: begin
                        s_r_next.state = IDLE;
                        s_r_next.active_gen = NONE;
                    end
                    START, STOP: begin
                        s_r_next.state = INIT_GEN;
                    end
                    BYTE: begin
                        s_r_next.state = INIT_GEN;
                        //Set the request bytes
                        case(s_r.byte_counter)
                            //Write the slave addr
                            'd0: begin
                                s_r_next.req_byte = {s_r.addr_slave, 1'b0}; //We're writing the slave addr
                            end
                            //Write the register address, (surrently only 8 bit support)
                            'd1: begin
                                s_r_next.req_byte = s_r.addr_reg;
                            end
                            //Reads or writes
                            default: begin
                                if (s_r.write_en) begin
                                    //Wait for wr valid
                                    s_r_next.state = t_states'((i_valid_wr_byte) ? INIT_GEN : REQ_CONTROL);
                                    s_r_next.req_byte = i_wr_byte;
                                    s_r_next.last_byte = s_r.byte_counter >= (s_r.burst_num + 'd2);
                                end else begin
                                    //Wait for rd ready
                                    s_r_next.state = t_states'((i_ready_rd_byte) ? INIT_GEN : REQ_CONTROL);
                                    s_r_next.last_byte = s_r.byte_counter >= (s_r.burst_num + 'd2 + 'd1);
                                    if (s_r.byte_counter == 'd2) begin
                                        s_r_next.req_byte = {s_r.addr_slave, 1'b1}; // Reading mode on bus
                                    end else begin
                                        s_r_next.req_byte = '0; 
                                    end
                                end
                            end
                        endcase
                    end
                endcase
                // NOTE: might cause problems while waiting for data in byte
                //mode?
                s_r_next.active_gen = s_r.active_gen_next;
            end
            //Delay state for gen modules to load the current I2C line values
            INIT_GEN: begin
                logic v_ready;
                case(s_r.active_gen)
                    START: begin
                        v_ready = i_start_ready;
                    end
                    BYTE: begin
                        v_ready = i_byte_ready;
                    end
                    STOP: begin
                        v_ready = i_stop_ready;
                    end
                    // TODO:Add failsave to this
                    default: v_ready = 1'b0;
                endcase
                if (v_ready) begin
                    s_r_next.state = REQ_GEN;
                end
            end
            REQ_GEN: begin //Sends out the request valid, and pop wr data if needed
                s_r_next.state = WAIT_GEN;
            end
            WAIT_GEN: begin
                logic v_done;
                case(s_r.active_gen)
                    START: begin
                        v_done = i_start_done;
                    end
                    BYTE: begin
                        v_done = i_wr_ack | i_wr_nack | i_rd_valid;
                    end
                    STOP: begin
                        v_done = i_stop_done;
                    end
                    default: v_done = 1'b0;
                endcase
                if (v_done) begin
                    s_r_next.state = END_GEN;
                    s_r_next.wr_ack = i_wr_ack;
                end
            end
            END_GEN: begin
                s_r_next.state = REQ_CONTROL;
                case (s_r.active_gen)
                    START: s_r_next.active_gen_next = BYTE;
                    STOP: begin
                        s_r_next.active_gen_next =
                            t_gen_states'((s_r.last_byte) ? NONE : START);
                    end
                    BYTE: begin
                        s_r_next.byte_counter++; //increment byte counter after req
                        case (s_r.byte_counter)
                            'd0: begin //Slave addr byte
                                //Slave should ack back, even in sccb mode
                                s_r_next.active_gen_next =
                                    t_gen_states'((s_r.wr_ack) ? BYTE : STOP);
                            end
                            'd1: begin //Reg addr byte
                                //Slave should ack back, even in sccb mode
                                if (s_r.wr_ack) begin
                                    if (s_r.write_en) begin
                                        s_r_next.active_gen_next = BYTE;
                                    end else begin
                                        s_r_next.active_gen_next =
                                            t_gen_states'((s_r.sccb_mode) ? STOP : START);
                                    end
                                end else begin
                                    s_r_next.active_gen_next = STOP;
                                end
                            end
                            default: begin //Data bytes
                                if (s_r.last_byte) begin
                                    //decide to repeat start or stop req
                                    if (~s_r.sccb_mode & i_valid) begin
                                        s_r_next.active_gen_next = START;
                                        s_r_next.state = REQ_LOAD;
                                    end else begin
                                        //No bursts for sccb mode
                                        s_r_next.active_gen_next = STOP;
                                    end
                                end else begin
                                end
                            end
                        endcase
                    end
                endcase
            end
            default: begin
                s_r_next.state = IDLE;
                s_r_next.active_gen = NONE;
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


