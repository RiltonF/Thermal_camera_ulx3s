`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module pixel_smoothing #(
    parameter int MAX_ADDR = 2**6-1,
    localparam int ADDRW = $clog2(MAX_ADDR)
) (
    input  logic i_clk,
    input  logic i_rst,
    input  logic i_start,
    input  logic             i_wr_valid,
    input  logic [ADDRW-1:0] i_wr_addr,
    input  logic [    8-1:0] i_wr_data,

    output logic             o_wr_valid,
    output logic [ADDRW-1:0] o_wr_addr,
    output logic [    8-1:0] o_wr_data
);
    logic             s_norm_valid;
    logic [ADDRW-1:0] s_norm_addr;
    logic [    8-1:0] s_norm_data;

    logic             s_wr_avg_valid;
    logic [ADDRW-1:0] s_wr_avg_addr;
    logic [    8-1:0] s_wr_avg_data;

    logic             s_rd_avg_valid;
    logic [ADDRW-1:0] s_rd_avg_addr;
    logic [    8-1:0] s_rd_avg_data;
    
    logic             s_avg_valid;
    logic [ADDRW-1:0] s_avg_addr;
    logic [   12-1:0] s_avg_calc;
    logic [    8-1:0] s_avg_old;

    logic             s_init_done, s_init_done_next;
    logic             s_init_mode, s_init_mode_next;

    always_comb begin
        //setup
        s_init_done_next = s_init_done;
        s_init_mode_next = s_init_mode;


        case({s_init_done, s_init_mode})
            //If init is not done and mode is not started
            //Start init mode when input is valid and at address 0
            2'b00: begin 
                if (i_wr_valid & i_wr_addr == '0) begin
                    s_init_mode_next = 1'b1;
                end
            end
            //While in init mode, if the address is at max, the init is done
            2'b01: begin 
                if (s_norm_valid & s_norm_addr >= MAX_ADDR) begin
                    s_init_mode_next = 1'b0;
                    s_init_done_next = 1'b1;
                end
            end
            default: begin 
                //Manual restart setting
                if (i_start) begin
                    s_init_mode_next = 1'b0;
                    s_init_done_next = 1'b0;
                end
            end
        endcase
    end

    assign o_wr_valid = s_avg_valid;
    assign o_wr_addr  = s_avg_addr;
    assign o_wr_data  = s_avg_calc;

    always_ff @(posedge i_clk) begin
        s_norm_valid <= i_wr_valid;
        s_norm_addr  <= i_wr_addr;
        s_norm_data  <= i_wr_data;

        s_avg_valid <= s_norm_valid;
        s_avg_addr  <= s_norm_addr;
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_avg_calc <= '0;
            s_init_mode <= '0;
            s_init_done <= '0;
        end else begin
            s_init_done <= s_init_done_next;
            s_init_mode <= s_init_mode_next;
            //just pass the norm data if still initializing
            if (s_init_done) begin
                s_avg_calc <= (((s_avg_old * 3) + s_norm_data) >> 2);
            end else begin
                s_avg_calc <= s_norm_data;
            end
        end
    end

    //Don't read when in init mode since you'll be reading and writing to the
    //same address
    assign s_rd_avg_valid = i_wr_valid & s_init_done;
    assign s_rd_avg_addr = i_wr_addr;
    assign s_avg_old = s_rd_avg_data;

    always_comb begin
        if (s_init_done) begin
            s_wr_avg_valid = s_avg_valid;
            s_wr_avg_addr  = s_avg_addr;
            s_wr_avg_data  = s_avg_calc;
        end else begin
            s_wr_avg_valid = s_norm_valid & s_init_mode;
            s_wr_avg_addr  = s_norm_addr;
            s_wr_avg_data  = s_norm_data;
        end
    end
    //Memory that stores averages
    mu_ram_1r1w #(
        .DW($bits(s_wr_avg_data)),
        .AW(ADDRW)
    ) inst_old_avg_mem (
        .clk(i_clk),
        //Write interface
        .we     (s_wr_avg_valid),
        .waddr  (s_wr_avg_addr),
        .wr     (s_wr_avg_data),
        //Read interface
        .re     (s_rd_avg_valid),
        .raddr  (s_rd_avg_addr),
        .rd     (s_rd_avg_data)
    );
endmodule


