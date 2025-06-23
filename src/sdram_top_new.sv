`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module sdram_top_new #(
    parameter p_clock_feq = 100_000_000,
    parameter int p_dram_burst_size = 8,
    parameter int p_dram_dataw = 16,
    parameter int p_dram_rows = 8192,
    parameter int p_dram_cols = 512,
    parameter int p_dram_banks= 4,
    localparam int c_addrw = $clog2(p_dram_rows),
    localparam int c_bankw = $clog2(p_dram_banks),
    localparam int c_roww = $clog2(p_dram_rows),
    localparam int c_colw = $clog2(p_dram_rows),
    localparam int c_req_addrw = c_bankw + c_colw + c_roww
) (
    input  logic                     i_dram_clk,
    input  logic                     i_rst,
    
    input  logic                     i_clk_wr_fifo, //pixel clock from camera
    input  logic                     i_wr_fifo_valid,
    input  logic [ p_dram_dataw-1:0] i_wr_fifo_data,
    output logic                     o_wr_fifo_ready,

    input  logic                     i_clk_rd_fifo, // clock from vga
    output logic                     o_rd_fifo_valid,
    output logic [ p_dram_dataw-1:0] o_rd_fifo_data,
    input  logic                     i_rd_fifo_ready,

    input  logic                     i_new_frame,
    input  logic                     i_new_line,

    /* ----- SDRAM Signals ----- */
    inout  tri   [ p_dram_dataw-1:0] io_dram_data,  /* Read/Write Data */
    output logic [      c_addrw-1:0] o_dram_addr,   /* Read/Write Address */
    output logic [      c_bankw-1:0] o_dram_ba,     /* Bank Address */
    output logic                     o_dram_ldqm,   /* Low byte data mask */
    output logic                     o_dram_udqm,   /* High byte data mask */
    output logic                     o_dram_we_n,   /* Write enable */
    output logic                     o_dram_cas_n,  /* Column address strobe */
    output logic                     o_dram_ras_n,  /* Row address strobe */
    output logic                     o_dram_cs_n,   /* Chip select */
    output logic                     o_dram_clk,    /* DRAM Clock */
    output logic                     o_dram_cke,    /* Clock Enable */

    output logic                     o_dram_initialized,

    input  logic [              1:0] i_debug_trig,
    output logic [              7:0] o_debug_status
);
    logic s_dram_clk;
    logic s_dram_rst;

    logic s_dram_ready;

    logic s_new_frame_sync;
    logic s_new_line_sync;

    logic                    s_load_rd_req_valid;
    logic [c_req_addrw-1:0]  s_load_rd_req_addr;
    logic                    s_load_rd_req_ready;

    assign s_dram_clk = i_dram_clk;

    assign s_load_rd_req_valid = s_new_line_sync;
    assign s_load_rd_req_addr = '0;

    xd inst_sync_frame (
        .clk_src(i_clk_rd_fifo),
        .clk_dst(s_dram_clk),
        .flag_src(i_new_frame),
        .flag_dst(s_new_frame_sync)
    );
    xd inst_sync_line(
        .clk_src(i_clk_rd_fifo),
        .clk_dst(s_dram_clk),
        .flag_src(i_new_line),
        .flag_dst(s_new_line_sync)
    );

    always_ff @(posedge s_dram_clk) begin
        if (s_dram_rst) begin
            o_dram_initialized <= '0;
        end else begin
            if (s_dram_ready) o_dram_initialized <= 1'b1;
        end
    end
    // // Full VGA frame / page size
    // localparam int c_full_frame_words = 640*480;
    // localparam int c_full_frame_pages = $rtoi($ceil(c_full_frame_words/512));
    // localparam int c_countw = $clog2(c_full_frame_pages);
    // typedef struct packed {
    //     logic                busy;
    //     logic                sdram_rw_en;
    //     logic                sdram_rw;
    //     logic [ c_addrw-1:0] sdram_addr;
    //     logic [ c_bankw-1:0] sdram_ba;
    //     logic [c_countw-1:0] read_row;
    //     logic [c_countw-1:0] write_row;
    //     logic                sdram_ready_latch;
    //     logic                read_fifo_reset;
    //     logic                new_frame;
    //     logic [$clog2(512):0] s_count;
    //     logic [$clog2(512):0] s_count_max;
    // } t_signals;
    //
    // t_signals s_r, s_r_next;
    //
    // `ifndef SIMULATION
    //     localparam t_signals c_signals_reset = '{default:'0};
    // `else
    //     localparam t_signals c_signals_reset = {'0};
    //     logic                d_busy;
    //     logic                d_sdram_rw_en;
    //     logic                d_sdram_rw;
    //     logic [c_countw-1:0] d_read_row;
    //     logic [c_countw-1:0] d_write_row;
    //     logic [ c_addrw-1:0] d_sdram_addr;
    //     assign d_busy = s_r.busy;
    //     assign d_read_row = s_r.read_row;
    //     assign d_write_row = s_r.write_row;
    //     assign d_sdram_addr = s_r.sdram_addr;
    //     assign d_sdram_rw = s_r.sdram_rw;
    //     assign d_sdram_rw_en = s_r.sdram_rw_en;
    // `endif
    //
    // logic s_overflow_addr;
    //
    // always_comb begin
    //     //init
    //     s_r_next = s_r;
    //
    //     s_r_next.sdram_ready_latch = s_sdram_ready;
    //
    //     //Catch the pulse for a new frame
    //     if (s_new_frame_sync) begin
    //         s_r_next.new_frame = 1'b1;
    //     end
    //
    // end

    //--------------------------------------------------------------------------------
    // Write Request
    //--------------------------------------------------------------------------------
    logic                     s_wr_valid;
    logic [p_dram_dataw-1:0]  s_wr_data;
    logic                     s_wr_ready;
    mu_fifo_async #(
        .DW(p_dram_dataw),
        .DEPTH(512*2),
        .THRESH_EMPTY(512)
    ) inst_write_req_fifo (
        .wr_clk     (i_clk_wr_fifo),
        .wr_nreset  (~i_rst),
        .wr_valid   (i_wr_fifo_valid),
        .wr_din     (i_wr_fifo_data),
        .wr_ready   (o_wr_fifo_ready),

        .rd_clk     (s_dram_clk),
        .rd_nreset  (~i_rst),
        .rd_valid   (s_wr_valid),
        .rd_dout    (s_wr_data),
        .rd_ready   (s_wr_ready)
    );

    logic                    s_wr_req_valid;
    logic [p_dram_dataw-1:0] s_wr_req_data [p_dram_burst_size];
    logic                    s_wr_req_ready;

    simple_widthadapt_1_to_x #(
        .p_iwidth (p_dram_dataw),
        .p_x      (p_dram_burst_size)
    ) int_wr_width_adapt_1_to_8 (
        .i_clk        (s_dram_clk),
        .i_rst        (s_dram_rst),
        .i_valid      (s_wr_valid),
        .i_data       (s_wr_data),
        .o_ready      (s_wr_ready),
        .o_valid      (s_wr_req_valid),
        .o_data_array (s_wr_req_data),
        .i_ready      (s_wr_req_ready)
    );


    //--------------------------------------------------------------------------------
    // Read Request
    //--------------------------------------------------------------------------------

    logic                    s_rd_req_valid;
    logic [c_req_addrw-1:0]  s_rd_req_addr;
    logic                    s_rd_req_ready;
    mu_fifo_sync #(
        .DW(c_req_addrw),
        .DEPTH(64)
    ) inst_read_req_fifo (
        .clk            (s_dram_clk),
        .rst            (s_dram_rst),
        .wr_valid       (s_load_rd_req_valid),
        .wr_data        (s_load_rd_req_addr),
        .wr_ready       (s_load_rd_req_ready),
        .rd_valid       (s_rd_req_valid),
        .rd_data        (s_rd_req_addr),
        .rd_ready       (s_rd_req_ready)
    );

    //--------------------------------------------------------------------------------
    // SDRAM Controller
    //--------------------------------------------------------------------------------
    logic                     s_rd_dram_valid;
    logic [p_dram_dataw-1:0]  s_rd_dram_data;
    logic s_debug;
    sdram_ctrl #(
        .ClockFreq(p_clock_feq),
        .BurstLength(8),
        .BankWidth(c_bankw), 
        .RowWidth(c_roww),
        .ColWidth(c_colw)
    ) sdram_ctrl (
        .i_sys_clk(s_dram_clk),
        .i_dram_clk(s_dram_clk),
        .i_rst_n(~s_dram_rst),

        .o_ready(s_dram_ready),

        .i_wr_req  (s_wr_req_valid),
        .i_wr_addr ('0), // TODO: update
        .i_wr_data (s_wr_req_data),
        .o_wr_ready(s_wr_req_ready),

        .i_rd_req (s_rd_req_valid),
        .i_rd_addr(s_rd_req_addr),
        .o_rd_ready(s_rd_req_ready),

        .o_rd_valid (s_rd_dram_valid),
        .o_rd_data (s_rd_dram_data),

        .o_debug(s_debug),

        .o_dram_addr, 
        .io_dram_data, 
        .o_dram_ba_0(o_dram_ba[0]), 
        .o_dram_ba_1(o_dram_ba[1]), 
        .o_dram_ldqm, 
        .o_dram_udqm, 
        .o_dram_we_n, 
        .o_dram_cas_n,
        .o_dram_ras_n,
        .o_dram_cs_n, 
        .o_dram_clk,  
        .o_dram_cke   
    );

    // assign o_debug_status = {s_rd_dram_valid,s_rd_req_ready, s_dram_ready,s_dram_clk, s_new_line_sync};
    // assign o_debug_status = {s_rd_dram_valid,s_rd_req_ready, s_dram_ready,s_dram_clk, s_wr_req_valid|i_wr_fifo_valid};
    // assign o_debug_status = {s_wr_ready,s_wr_valid, s_dram_ready,s_dram_clk, s_wr_req_ready,s_wr_req_valid, s_wr_req_valid|s_wr_valid};
    // assign o_debug_status = {s_wr_req_data[0], s_wr_req_valid};
    // assign o_debug_status = {io_dram_data,s_dram_ready, s_rd_req_valid};
    // assign o_debug_status = {s_rd_dram_data, s_rd_dram_valid};
    //--------------------------------------------------------------------------------
    // Read data from SDRAM
    //--------------------------------------------------------------------------------
    logic s_rd_data_ready;
    logic [15:0]s_fill;
    logic [15:0]s_rfill;
    // assign o_debug_status = {s_rd_dram_data[2:0], s_rd_dram_valid,io_dram_data[2:0], s_rd_req_valid};
    // assign o_debug_status = {s_rd_dram_data,s_rd_data_ready,s_dram_clk, s_rd_dram_valid};
    mu_fifo_async #(
        .DW(p_dram_dataw),
        .DEPTH(512*2)
    ) inst_sdram_rd_fifo (
        .wr_clk     (s_dram_clk),
        .wr_nreset  (~i_rst),
        .wr_valid   (s_rd_dram_valid),
        .wr_din     (s_rd_dram_data),
        .wr_ready   (s_rd_data_ready),
        .wr_used    (s_fill),

        .rd_clk     (i_clk_rd_fifo),
        .rd_nreset  (~i_rst),
        .rd_valid   (o_rd_fifo_valid),
        .rd_dout    (o_rd_fifo_data),
        .rd_ready   (i_rd_fifo_ready),
        .rd_used    (s_rfill)
    );
    // assign o_debug_status = {s_fill,s_dram_clk, s_rd_dram_valid|s_rd_req_valid};
    assign o_debug_status = {s_rfill,s_dram_clk, s_rd_dram_valid|s_rd_req_valid};
    // assign o_debug_status = {s_rd_dram_data,s_dram_clk, s_rd_dram_valid|s_rd_req_valid};

    //--------------------------------------------------------------------------------
    // Clocks and resets
    //--------------------------------------------------------------------------------


    reset_sync inst_sdram_reset_sync (
        .i_clk(s_dram_clk),
        .i_async_rst(i_rst),
        .o_rst(s_dram_rst)
    );
    // xd xd_sdram_reset (
    //     .clk_src(i_clk),
    //     .flag_src(i_rst),
    //     .clk_dst(s_dram_clk),
    //     .flag_dst(s_dram_rst)
    // );
endmodule


