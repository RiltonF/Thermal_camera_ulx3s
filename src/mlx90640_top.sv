`default_nettype none
`timescale 1ns / 1ps
import package_i2c::t_i2c_cmd_16b;
import package_i2c::BURST_WIDTH_16b;

module mlx90640_top #(
    parameter int p_slave_addr = 'h33,
    parameter int p_delay_const = 2**25-1,
    localparam c_mlx_addrw = $clog2(32*24+64)
) (
    input  logic i_clk,
    input  logic i_rst,
    input  logic [1:0] i_trig,
    output logic [7:0] o_debug,

    input  logic                   i_fb_rd_valid,
    input  logic [c_mlx_addrw-1:0] i_fb_rd_addr,
    output logic            [16:0] o_fb_rd_data,

    inout logic b_sda,
    inout logic b_scl
);
    localparam c_ram_start_addr = 16'h0400;
    typedef struct packed {
        logic [BURST_WIDTH_16b:0] words;
        logic page_number;
        logic is_rom_data;
    } t_rd_log;

    logic        s_cmd_log_valid;
    t_rd_log     s_cmd_log_data;
    logic        s_cmd_log_ready;

    logic         s_cmd_valid;
    t_i2c_cmd_16b s_cmd_data;
    logic         s_cmd_ready;
    logic         s_cmd_ack;

    logic        s_rd_log_valid;
    t_rd_log     s_rd_log_data;
    logic        s_rd_log_ready;

    logic        s_wr_fifo_valid;
    logic [15:0] s_wr_fifo_data;
    logic        s_wr_fifo_ready;

    logic        s_cmd_rd_fifo_valid;
    logic        s_cmd_rd_fifo_ready;
    logic        s_rd_fifo_valid;
    logic [15:0] s_rd_fifo_data;
    logic        s_rd_fifo_ready;

    logic        s_page_number;

    logic                   s_wr_fb_valid;
    logic            [16:0] s_wr_fb_data;
    logic [c_mlx_addrw-1:0] s_wr_fb_addr;
    //--------------------------------------------------------------------------------
    //MLX controller and I2C controller
    //--------------------------------------------------------------------------------
    mlx90640_controller #(
        .p_sccb_mode   (1'b0),
        .p_slave_addr  (p_slave_addr),
        .p_delay_const (0)
        // .p_delay_const (p_delay_const)
    ) inst_mlx_controller (
        .i_clk           (i_clk),
        .i_rst           (i_rst),
        .i_start         (i_trig[0]),
        .o_page_number   (s_page_number),
        .o_cmd_valid     (s_cmd_valid),
        .o_cmd_data      (s_cmd_data),
        .i_cmd_ready     (s_cmd_ready & s_cmd_log_ready),
        .i_cmd_ack       (s_cmd_ack),
        .o_wr_fifo_valid (s_wr_fifo_valid),
        .o_wr_fifo_data  (s_wr_fifo_data),
        .i_wr_fifo_ready (s_wr_fifo_ready),
        .i_rd_fifo_valid (s_cmd_rd_fifo_valid),
        .i_rd_fifo_data  (s_rd_fifo_data),
        .o_rd_fifo_ready (s_cmd_rd_fifo_ready)
    );

    logic        s_rd_8b_valid;
    logic [7:0]  s_rd_8b_data;
    logic        s_rd_8b_ready;

    i2c_master_wrapper_16b #(
        .CMD_FIFO(0),
        .RD_FIFO(0),
        .WR_FIFO(1)
    ) inst_i2c_master_mlx(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_enable(1'b1),

        .i_cmd_fifo_valid (s_cmd_valid),
        .i_cmd_fifo_data  (s_cmd_data),
        .o_cmd_fifo_ready (s_cmd_ready),
        .o_cmd_ack        (s_cmd_ack),

        .i_wr_fifo_valid (s_wr_fifo_valid),
        .i_wr_fifo_data  (s_wr_fifo_data),
        .o_wr_fifo_ready (s_wr_fifo_ready),

        .o_rd_fifo_valid (s_rd_8b_valid),
        .o_rd_fifo_data  (s_rd_8b_data),
        .i_rd_fifo_ready (s_rd_8b_ready),

        .b_sda(b_sda),
        .b_scl(b_scl)
    );


    //Module to combine two 8b read data into one
    mu_widthadapt_1_to_2 #(
        .IW(8)
    )inst_width_adapt (
        .clk(i_clk),
        .rst(i_rst),

        .wr_valid (s_rd_8b_valid),
        .wr_data  (s_rd_8b_data),
        .wr_ready (s_rd_8b_ready),

        .rd_valid (s_rd_fifo_valid),
        .rd_data  (s_rd_fifo_data),
        .rd_ready (s_rd_fifo_ready)
    );

    //--------------------------------------------------------------------------------
    // CMD log fifo for arbitration of the read data
    //--------------------------------------------------------------------------------
    assign s_cmd_log_valid = s_cmd_valid & ~s_cmd_data.we;
    `ifndef SIMULATION
        assign s_cmd_log_data = '{
            words: s_cmd_data.burst_num+1'b1,
            page_number: s_page_number,
            is_rom_data: s_cmd_data.addr_reg == c_ram_start_addr
        };
    `else
        assign s_cmd_log_data = '{
            s_cmd_data.burst_num+1'b1,
            s_page_number,
            s_cmd_data.addr_reg == c_ram_start_addr
            };
    `endif

    mu_fifo_sync #(
        .DW($bits(s_cmd_log_data)),
        .DEPTH(8)
    ) inst_rd_log_fifo (
        .clk            (i_clk),
        .rst            (i_rst),
        //trigger only on reads
        .wr_valid       (s_cmd_log_valid),
        .wr_data        (s_cmd_log_data),
        .wr_ready       (s_cmd_log_ready),

        .rd_valid       (s_rd_log_valid),
        .rd_data        (s_rd_log_data),
        .rd_ready       (s_rd_log_ready)
    );
    //--------------------------------------------------------------------------------
    // Read data arbiter
    //--------------------------------------------------------------------------------
    assign s_cmd_rd_fifo_valid =
        s_rd_fifo_valid & s_rd_log_valid & ~s_rd_log_data.is_rom_data;
    assign s_wr_fb_valid =
        s_rd_fifo_valid & s_rd_log_valid & s_rd_log_data.is_rom_data;

    typedef enum {IDLE, STATUS_READ, ROM_READ} t_arb_states;

    typedef struct packed {
        t_arb_states state;
        logic [BURST_WIDTH_16b:0] word_counter;
    }t_signals;
    
    t_signals s_r, s_r_next;

    `ifndef SIMULATION
        t_signals c_signals_reset = '{state: IDLE, default:'0};
    `else
        t_signals c_signals_reset = {IDLE, '0};
        t_arb_states d_state;
        logic [BURST_WIDTH_16b:0] d_word_counter;
        assign d_state = s_r.state;
        assign d_word_counter = s_r.word_counter;
    `endif

    always_comb begin
        s_r_next = s_r;

        s_rd_log_ready = 1'b0;
        s_rd_fifo_ready = 1'b0;

        case (s_r.state)
            IDLE: begin
                if (s_rd_log_valid) begin
                    s_r_next.word_counter = '0;
                    s_r_next.state = t_arb_states'(
                        (s_rd_log_data.is_rom_data) ? ROM_READ : STATUS_READ);
                end
            end
            STATUS_READ: begin
                if (s_cmd_rd_fifo_ready) begin
                    s_rd_log_ready = 1'b1;
                    s_rd_fifo_ready = 1'b1;
                    s_r_next.state = IDLE;
                end
            end
            ROM_READ: begin
                if (s_rd_fifo_valid) begin
                    s_r_next.word_counter++;
                    s_rd_fifo_ready <= 1'b1;
                    if (s_r_next.word_counter >= s_rd_log_data.words) begin
                        s_rd_log_ready <= 1'b1;
                        s_r_next.state = IDLE;
                    end
                end
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

    //--------------------------------------------------------------------------------
    // Frambuffer ram for MLX read data
    //--------------------------------------------------------------------------------

    assign s_wr_fb_data = {s_rd_fifo_data, s_rd_log_data.page_number};
    assign s_wr_fb_addr = s_r.word_counter;

    // assign o_debug = {s_wr_fb_valid, s_wr_fb_addr[6:0]};
    assign o_debug = {i_fb_rd_valid, i_fb_rd_addr[6:0]};

    mu_ram_1r1w #(
        .DW($bits(s_wr_fb_data)),
        .AW(c_mlx_addrw)
    ) inst_mlx_fb_mem (
        .clk(i_clk),
        //Write interface
        .we     (s_wr_fb_valid),
        .waddr  (s_wr_fb_addr),
        .wr     (s_wr_fb_data),
        //Read interface
        .re     (i_fb_rd_valid),
        .raddr  (i_fb_rd_addr),
        .rd     (o_fb_rd_data)
    );
endmodule
