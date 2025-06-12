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
    localparam c_eeprom_start_addr = 16'h2400;

    typedef struct packed {
        logic [BURST_WIDTH_16b:0] words;
        logic page_number;
        logic is_ram_data;
        logic is_eeprom_data;
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

    logic                   s_wr_eeprom_valid;
    logic                   s_wr_ram_valid;

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
        .I2C_FREQ(200_000), //TODO: fix this 
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
            is_ram_data: s_cmd_data.addr_reg == c_ram_start_addr,
            is_eeprom_data: s_cmd_data.addr_reg == c_eeprom_start_addr
        };
    `else
        assign s_cmd_log_data = '{
            s_cmd_data.burst_num+1'b1,
            s_page_number,
            s_cmd_data.addr_reg == c_ram_start_addr,
            s_cmd_data.addr_reg == c_eeprom_start_addr
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
        s_rd_fifo_valid & s_rd_log_valid & ~s_rd_log_data.is_ram_data & ~s_rd_log_data.is_eeprom_data;
    assign s_wr_ram_valid =
        s_rd_fifo_valid & s_rd_log_valid & s_rd_log_data.is_ram_data & ~s_rd_log_data.is_eeprom_data;
    assign s_wr_eeprom_valid =
        s_rd_fifo_valid & s_rd_log_valid & ~s_rd_log_data.is_ram_data & s_rd_log_data.is_eeprom_data;

    typedef enum {IDLE, STATUS_READ, OTHER_READ} t_arb_states;

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
                        (s_rd_log_data.is_ram_data | s_rd_log_data.is_eeprom_data)
                            ? OTHER_READ : STATUS_READ);
                end
            end
            STATUS_READ: begin
                if (s_cmd_rd_fifo_ready) begin
                    s_rd_log_ready = 1'b1;
                    s_rd_fifo_ready = 1'b1;
                    s_r_next.state = IDLE;
                end
            end
            OTHER_READ: begin
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
    typedef struct packed {
        logic signed [5:0] offset;
        logic signed [5:0] alpha;
        logic [2:0] kta;
        logic       outlier;
    } t_eeprom_data;
    t_eeprom_data           s_eeprom_data;

    logic            [15:0] s_wr_read_data;
    logic [c_mlx_addrw-1:0] s_wr_read_addr;

    logic                   s_pg0_valid, s_pg1_valid;
    logic                   s_wr_fb_page_number;
    logic                   s_wr_fb_valid;
    logic                   s_wr_fb_valid_page;
    logic signed     [15:0] s_wr_fb_data;
    logic [c_mlx_addrw-1:0] s_wr_fb_addr;
    logic            [15:0] s_wr_old_data;

    assign s_wr_fb_valid_page = s_wr_fb_valid & ((s_wr_fb_page_number)? s_pg1_valid: s_pg0_valid);

    assign s_wr_read_data = s_rd_fifo_data;
    assign s_wr_read_addr = s_r.word_counter;

    //Clock in valid data to give eeprom mem time to read data
    always_ff @(posedge i_clk) begin
        s_wr_fb_valid <= s_wr_ram_valid;
        s_wr_fb_addr <= s_wr_read_addr;
        s_wr_fb_data <= s_wr_read_data;
        s_wr_fb_page_number <= s_rd_log_data.page_number;
        //To be used for dead pixels
        if (s_wr_fb_valid) s_wr_old_data <= s_wr_fb_data;
    end

    // NOTE: might need to add two read ports
    mu_ram_1r1w #(
        .DW($bits(s_wr_read_data)),
        .AW(c_mlx_addrw)
    ) inst_mlx_eeprom_dump_mem (
        .clk(i_clk),
        //Write interface
        .we     (s_wr_eeprom_valid),
        .waddr  (s_wr_read_addr),
        .wr     (s_wr_read_data),
        //Read interface
        .re     (s_wr_ram_valid),
        .raddr  (s_wr_read_addr + 'd64), //first 64 bits of eeprom is not pixel data
        .rd     (s_eeprom_data)
    );

    assign o_debug = s_eeprom_data;

    // NOTE: Change to memory with a read valid?
    mlx90640_subpages_rom_sync inst_mlx_subpages_rom (
        .clk(i_clk),
        .addr(s_wr_read_addr),
        .data_pg0(s_pg0_valid),
        .data_pg1(s_pg1_valid)
    );

    //Raw data - offset from eeprom, offset data is sign extended
    logic signed [15:0] s_norm_data, s_max_data, s_min_data, s_range_data;
    logic signed [15:0] s_max_data_running, s_min_data_running;
    assign s_norm_data = 
        $signed(s_wr_fb_data) - $signed({{10{s_eeprom_data.offset[5]}}, s_eeprom_data.offset});

    always_ff @(posedge i_clk) begin
        if (s_wr_fb_valid_page) begin
            if (s_wr_fb_addr == '0) begin
                s_min_data <= s_norm_data;
                s_max_data <= s_norm_data;
                s_min_data_running <= s_min_data;
                s_max_data_running <= s_max_data;
                s_range_data <= ((s_max_data - s_min_data) == 0) ? 16'sb1 : s_max_data - s_min_data;
            end else begin
                s_min_data <= (s_norm_data < s_min_data) ? s_norm_data : s_min_data;
                s_max_data <= (s_norm_data > s_max_data) ? s_norm_data : s_max_data;
            end
        end
    end

    logic                   s_fb_rd_valid;
    logic signed     [15:0] s_fb_rd_data, s_fb_rd_data_1;
    logic signed     [31:0] s_fb_rd_data_2, s_fb_rd_data_3;
    logic [c_mlx_addrw-1:0] s_fb_rd_addr;
    logic signed     [15:0] s_scale;

    // always_ff @(posedge i_clk) s_fb_rd_data_1 <=(s_fb_rd_data - s_min_data_running);
    // always_ff @(posedge i_clk) s_fb_rd_data_2 <= s_fb_rd_data_1 * 16'sd255;
    // always_ff @(posedge i_clk) s_fb_rd_data_3 <= s_fb_rd_data_2 / s_range_data;
    // always_ff @(posedge i_clk) s_fb_rd_data_1 <=(s_fb_rd_data - s_min_data_running);
    // always_ff @(posedge i_clk) s_fb_rd_data_2 <= s_fb_rd_data_1 * 16'sd255;
    // always_ff @(posedge i_clk) s_fb_rd_data_3 <= (8'd255 << 12)/ s_range_data;
    // assign o_fb_rd_data = s_fb_rd_data_3;
    assign o_fb_rd_data = s_fb_rd_data;

    //Read pixel data from page pattern and eeprom data
    mu_ram_1r1w #(
        .DW($bits(s_wr_read_data)),
        .AW(c_mlx_addrw)
    ) inst_mlx_fb_mem (
        .clk(i_clk),
        //Write interface
        //Filter the subpages based on page number
        .we     (s_wr_fb_valid_page),
        .waddr  (s_wr_fb_addr),
        //use old valid data to replace broken pixel, 0 means dead pixel
        .wr     ((s_eeprom_data == '0) ? s_wr_old_data : s_norm_data),
        //Read interface
        .re     (i_fb_rd_valid),
        .raddr  (i_fb_rd_addr),
        .rd     (s_fb_rd_data)
    );

endmodule
