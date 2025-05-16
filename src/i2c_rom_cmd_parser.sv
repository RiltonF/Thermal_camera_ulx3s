`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
import package_i2c::*;

module i2c_rom_cmd_parser #(
    parameter bit p_sccb_mode = 1'b1,
    parameter int p_slave_addr = 'h21,
    parameter bit p_wr_mode = 1'b1,
    parameter int p_rom_addr_width = 8,
    parameter int p_delay_const = 2**25-1
) (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_start,
    input  logic [15:0] i_data,
    output logic [p_rom_addr_width-1:0] o_addr,
    output logic o_done,

    output logic o_cmd_valid,
    output t_i2c_cmd o_cmd_data,
    output logic [7:0] o_wr_data,
    input  logic i_cmd_ready
    
);
    typedef enum {
        IDLE=0,
        CMD_LOAD=1,
        CMD_REQ=2,
        CMD_WAIT=3,
        DELAY=4
    } t_states;

    typedef struct packed {
        t_states state;
        logic [$clog2(p_delay_const)-1:0] delay_timer;
        logic [p_rom_addr_width-1:0] addr;
        logic done;
        logic [15:0] rom_data;
    } t_signals;


    t_signals s_r, s_r_next;

    assign o_addr = s_r.addr;
    assign o_cmd_valid = (s_r.state == CMD_REQ);
    assign o_done = s_r.done;
    assign o_wr_data = s_r.rom_data[7:0];

    `ifndef SIMULATION
        assign o_cmd_data = '{
            we: p_wr_mode,
            sccb_mode: p_sccb_mode,
            addr_slave: p_slave_addr,
            addr_reg: s_r.rom_data[15:8],
            burst_num:'0};
        localparam t_signals c_signals_reset = 
            '{state:IDLE,default:'0};
    `else
        t_states d_state;
        logic [$clog2(p_delay_const)-1:0] d_delay_timer;
        logic [p_rom_addr_width-1:0] d_addr;
        logic d_done;
        logic [15:0] d_rom_data;
        assign d_state = s_r.state;
        assign d_delay_timer = s_r.delay_timer;
        assign d_addr = s_r.addr;
        assign d_done = s_r.done;
        assign d_rom_data = s_r.rom_data;
        localparam t_signals c_signals_reset = 
            '{IDLE,'0,'0,'0,'0};
        assign o_cmd_data = '{
            p_wr_mode,
            p_sccb_mode,
            p_slave_addr,
            s_r.rom_data[15:8],
            '0};
    `endif


    always_comb begin
        s_r_next = s_r;
        case(s_r.state)
            IDLE: begin
                if (i_start) begin
                    s_r_next.addr = '0;
                    s_r_next.state = CMD_LOAD;
                    s_r_next.done = 1'b0;
                end
            end
            CMD_LOAD: begin
                case(i_data)
                    16'hFFFF: begin
                        s_r_next.state = IDLE;
                        s_r_next.done = 1'b1;
                        s_r_next.addr = '0;
                    end
                    16'hFFF0: begin
                        s_r_next.state = DELAY;
                        s_r_next.delay_timer = p_delay_const;
                        s_r_next.addr++;
                    end
                    default: begin
                        if (i_cmd_ready) begin //Wait for ready
                            s_r_next.state = CMD_REQ;
                            s_r_next.rom_data = i_data;
                        end
                    end
                endcase
            end
            CMD_REQ: begin
                s_r_next.state = CMD_WAIT;
                s_r_next.addr++;
            end
            CMD_WAIT: begin
                if (i_cmd_ready) begin
                    s_r_next.state = CMD_LOAD;
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


