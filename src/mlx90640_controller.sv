`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
import package_i2c::t_i2c_cmd_16b;

module mlx90640_controller #(
    parameter bit p_sccb_mode = 1'b0,
    parameter int p_slave_addr = 6'h33,
    parameter int p_delay_const = 2**25-1
) (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_start,
    output logic o_done,

    output logic o_cmd_valid,
    output t_i2c_cmd_16b o_cmd_data,
    input  logic i_cmd_ready,
    input  logic i_cmd_ack,

    output logic o_page_number,

    //WR Data interface
    output logic        o_wr_fifo_valid,
    output logic [15:0] o_wr_fifo_data,
    input  logic        i_wr_fifo_ready,

    //From Read Data FIFO
    input  logic        i_rd_fifo_valid,
    input  logic [15:0] i_rd_fifo_data,
    output logic        o_rd_fifo_ready
);
    typedef enum {
        IDLE=0,
        CMD_LOAD=1,
        CMD_REQ=2,
        CMD_WAIT=3,
        CMD_CONTROL=4,
        DELAY=5
    } t_states;

    typedef enum {
        NONE=0,
        STATUS_READ=1,
        RAM_READ=2,
        STATUS_WRITE=3
    } t_cmd;

    typedef struct packed {
        t_states state;
        t_cmd cmd_type;
        t_i2c_cmd_16b cmd_data;
        logic [$clog2(p_delay_const)-1:0] delay_timer;
        logic done;
        logic [15:0] read_data;
        logic [15:0] write_data;
        logic ack;
        logic init;
    } t_signals;

    t_signals s_r, s_r_next;

    `ifndef SIMULATION
        localparam t_signals c_signals_reset = 
            '{state:IDLE, cmd_type:NONE, default:'0};
    `else
        localparam t_signals c_signals_reset = 
            {IDLE, NONE, '0};

        t_states d_state;
        t_cmd d_cmd_type;
        t_i2c_cmd_16b d_cmd_data;
        logic [$clog2(p_delay_const)-1:0] d_delay_timer;
        logic d_done;
        logic [15:0] d_read_data;
        logic [15:0] d_write_data;
        logic d_ack;
        logic d_init;
        assign d_state = s_r.state;
        assign d_cmd_type = s_r.cmd_type;
        assign d_cmd_data = s_r.cmd_data;
        assign d_delay_timer = s_r.delay_timer;
        assign d_done = s_r.done;
        assign d_read_data = s_r.read_data;
        assign d_write_data = s_r.write_data;
        assign d_ack = s_r.ack;
        assign d_init = s_r.init;
    `endif

    localparam c_status_register = 16'h8000;
    localparam c_status_reset_val = 16'h0030;
    localparam c_control_register = 16'h800D;
    localparam c_ram_start_addr = 16'h0400;
    // localparam c_ram_read_words = 5;
    localparam c_ram_read_words = 32*24+64;

    assign o_done = s_r.done;

    assign o_cmd_valid = (s_r.state == CMD_REQ);
    assign o_cmd_data = s_r.cmd_data;

    assign o_wr_fifo_valid = o_cmd_valid & s_r.cmd_data.we;
    assign o_wr_fifo_data = s_r.write_data;

    //Only pop the read if checking status,
    //don't pop the rd data for the ram reads because another module handles it
    assign o_rd_fifo_ready = (s_r.state == CMD_CONTROL) 
                           & (s_r.cmd_type == STATUS_READ)
                           & ~s_r.cmd_data.we;

    assign o_page_number = s_r.read_data[0]; //Read data [0] contains sub page

    always_comb begin
        s_r_next = s_r;
        case(s_r.state)
            IDLE: begin
                if (i_start) begin
                    s_r_next.state = CMD_LOAD;
                    s_r_next.cmd_type = STATUS_READ;
                    s_r_next.done = 1'b0;
                end
            end
            CMD_LOAD: begin
                //The write check is not really needed for reads, but it's
                //cleaner to check it before sending requests
                if (i_cmd_ready & i_wr_fifo_ready) begin
                    s_r_next.state = CMD_REQ;
                end

                s_r_next.cmd_data.addr_slave = p_slave_addr;
                s_r_next.cmd_data.sccb_mode = p_sccb_mode;
                case(s_r.cmd_type)
                    STATUS_READ: begin
                        s_r_next.cmd_data.we = 1'b0;
                        s_r_next.cmd_data.addr_reg = c_status_register;
                        s_r_next.cmd_data.burst_num = '0;
                    end
                    STATUS_WRITE: begin
                        s_r_next.cmd_data.we = 1'b1;
                        s_r_next.cmd_data.addr_reg = c_status_register;
                        s_r_next.cmd_data.burst_num = '0;
                        s_r_next.write_data = c_status_reset_val;
                    end
                    RAM_READ: begin
                        s_r_next.cmd_data.we = 1'b0;
                        s_r_next.cmd_data.addr_reg = c_ram_start_addr;
                        s_r_next.cmd_data.burst_num = c_ram_read_words - 1'b1;
                    end
                    default: begin
                        s_r_next.state = IDLE;
                    end
                endcase
            end
            CMD_REQ: begin
                s_r_next.state = CMD_WAIT;
            end
            CMD_WAIT: begin
                if (i_rd_fifo_valid & ~s_r.cmd_data.we) begin
                    s_r_next.read_data = i_rd_fifo_data;
                end

                if (i_cmd_ready) begin
                    s_r_next.state = CMD_CONTROL;
                    s_r_next.ack = i_cmd_ack;
                end
            end
            CMD_CONTROL: begin
                if(s_r.ack) begin
                    case(s_r.cmd_type)
                        STATUS_READ: begin
                            //New data is availabe if bit [3] is high
                            if(s_r.read_data[3]) begin
                                //Continue to reading ram
                                s_r_next.state = CMD_LOAD;
                                s_r_next.cmd_type = RAM_READ;
                            end else begin
                                //Need to delay and try reading again for new
                                //data
                                s_r_next.state = DELAY;
                                s_r_next.cmd_type = STATUS_READ;
                                s_r_next.delay_timer = p_delay_const;
                            end
                        end
                        RAM_READ: begin
                            //Continue to reset status
                            s_r_next.state = CMD_LOAD;
                            s_r_next.cmd_type = STATUS_WRITE;
                        end
                        STATUS_WRITE: begin
                            //We'll delay after writing to give the slave some
                            //time to load new data
                            // s_r_next.state = IDLE;
                            s_r_next.state = DELAY;
                            s_r_next.cmd_type = STATUS_READ;
                            s_r_next.delay_timer = p_delay_const;
                        end
                        default: begin
                            s_r_next.state = IDLE;
                            s_r_next.cmd_type = NONE;
                        end
                    endcase
                end else begin
                    //We got no ack back from slave
                    s_r_next.state = IDLE;
                    s_r_next.cmd_type = NONE;
                end
            end
            DELAY: begin
                s_r_next.delay_timer--;
                if (s_r.delay_timer == '0) begin
                    s_r_next.state = CMD_LOAD;
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


