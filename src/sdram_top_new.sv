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
    localparam int c_colw = $clog2(p_dram_cols),
    localparam int c_req_addrw = c_bankw + c_colw + c_roww
) (
    input  logic                     i_dram_clk,
    input  logic                     i_rst,
    
    input  logic                     i_clk_wr_fifo, //pixel clock from camera
    input  logic                     i_wr_fifo_valid,
    input  logic [ p_dram_dataw+1:0] i_wr_fifo_data,
    output logic                     o_wr_fifo_ready,

    input  logic                     i_clk_rd_fifo, // clock from vga
    output logic                     o_rd_fifo_valid,
    output logic [ p_dram_dataw-1:0] o_rd_fifo_data,
    input  logic                     i_rd_fifo_ready,

    input  logic                     i_new_frame,
    input  logic                     i_new_line,

    /* ----- SDRAM Signals ----- */
    (* keep *) inout  logic [ p_dram_dataw-1:0] io_dram_data,  /* Read/Write Data */
    (* keep *) output logic [      c_addrw-1:0] o_dram_addr,   /* Read/Write Address */
    (* keep *) output logic [      c_bankw-1:0] o_dram_ba,     /* Bank Address */
    (* keep *) output logic                     o_dram_ldqm,   /* Low byte data mask */
    (* keep *) output logic                     o_dram_udqm,   /* High byte data mask */
    (* keep *) output logic                     o_dram_we_n,   /* Write enable */
    (* keep *) output logic                     o_dram_cas_n,  /* Column address strobe */
    (* keep *) output logic                     o_dram_ras_n,  /* Row address strobe */
    (* keep *) output logic                     o_dram_cs_n,   /* Chip select */
    (* keep *) output logic                     o_dram_clk,    /* DRAM Clock */
    (* keep *) output logic                     o_dram_cke,    /* Clock Enable */

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

    // assign s_load_rd_req_valid = s_new_line_sync;
    // assign s_load_rd_req_addr = '0;

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


    // Full VGA frame / page size
    localparam int c_full_frame_words = 640*480;
    localparam int c_vga_rows = 480;
    localparam int c_vga_cols = 640;
    localparam int c_req_per_row = c_vga_cols / p_dram_burst_size;

    typedef struct packed {
        logic                busy;
        logic [ c_colw-1:0] req_col;
        logic [ c_roww-1:0] req_row;
        logic [c_bankw-1:0] req_bank;
        logic [$clog2(c_vga_rows):0] row_count;
        logic [$clog2(c_vga_rows):0] row_count_max;
        logic [$clog2(c_req_per_row):0] req_count;
    } t_signals;

    t_signals s_r, s_r_next;

    `ifndef SIMULATION
        localparam t_signals c_signals_reset = '{default:'0};
    `else
        localparam t_signals c_signals_reset = '0;
        logic                d_busy;
        logic [ c_colw-1:0] d_req_col;
        logic [ c_roww-1:0] d_req_row;
        logic [c_bankw-1:0] d_req_bank;
        logic [$clog2(c_vga_rows):0] d_row_count;
        logic [$clog2(c_req_per_row):0] d_req_count;
        assign d_busy = s_r.busy;
        assign d_req_col = s_r.req_col;
        assign d_req_row= s_r.req_row;
        assign d_req_bank= s_r.req_bank;
        assign d_row_count= s_r.row_count;
        assign d_req_count= s_r.req_count;
        assign s_dram_rst = i_rst;
    `endif

    always_comb begin
        logic [c_roww:0] v_row_ptr_offset;
        logic [c_roww-1:0] v_row_ptr_start;
        logic [c_colw-1:0] v_col_ptr_start;
        logic [c_colw+c_roww-1:0] v_ptr;
        logic [c_req_addrw-1:0]  v_debug_addr;

        //init
        s_r_next = s_r;

        // o_debug_status = s_r.row_count_max>>4;

        // Calculate the pixel offsets and starts for a given row
        v_row_ptr_offset = (s_r.row_count>>2) + ((s_r.row_count>>2)<<2); // row * 1.25
        v_row_ptr_start = (s_r.row_count % 4) + v_row_ptr_offset;
        v_col_ptr_start = ((s_r.row_count % 4) << 7); //times by 128

        if (s_new_frame_sync) begin
            //Reset the row counter on a new frame
            s_r_next.row_count = '0;
            if(s_r.row_count > s_r.row_count_max) s_r_next.row_count_max = s_r.row_count;
        end else if (s_new_line_sync) begin
            //Increment on a new line
            s_r_next.row_count++;
            s_r_next.req_row = v_row_ptr_start;
            s_r_next.req_col = v_col_ptr_start;
            s_r_next.req_bank = '0; //only using bank 0
            s_r_next.req_count = '0;
            s_r_next.busy = 1'b1;
        end

        v_ptr = {s_r.req_row, s_r.req_col} + p_dram_burst_size;
        if (s_r.busy & s_load_rd_req_ready) begin
            s_r_next.req_count++;
            //Increment the pointer
            {s_r_next.req_row, s_r_next.req_col} = v_ptr;
            if (s_r.req_count >= (c_req_per_row - 1)) begin
            // if (s_r.req_count >= 3) begin
                s_r_next.busy = 1'b0;
            end
        end

        //output assignments
        s_load_rd_req_valid = s_r.busy;
        s_load_rd_req_addr = {s_r.req_bank, s_r.req_col, s_r.req_row};
        v_debug_addr = {s_r.req_bank, s_r.req_row, s_r.req_col};
    end

    always_ff @(posedge s_dram_clk) begin
        if (s_dram_rst) begin
            s_r <= c_signals_reset;
        end else begin
            s_r <= s_r_next;
        end
    end

    //--------------------------------------------------------------------------------
    // Write Request
    //--------------------------------------------------------------------------------
    logic                     s_wr_valid;
    logic [p_dram_dataw+1:0]  s_wr_data;
    logic                     s_wr_ready;
    mu_fifo_async #(
        .DW(p_dram_dataw+2),
        .DEPTH(512*2)
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
        .i_data       (s_wr_data>>2),
        .o_ready      (s_wr_ready),
        .o_valid      (s_wr_req_valid),
        .o_data_array (s_wr_req_data),
        .i_ready      (s_wr_req_ready)
    );

    logic [c_req_addrw-1:0]  s_wr_req_addr;

    logic [c_colw+c_roww-1:0] s_wr_ptr;
    logic [c_colw-1:0] s_wr_col;
    logic [c_roww-1:0] s_wr_row;
    logic s_trig;

    always_comb begin
        {s_wr_row, s_wr_col} = s_wr_ptr<<3; //we're counting by bursts, not words
        s_wr_req_addr = {2'b0,s_wr_col,s_wr_row};
    end
    
    always_ff @(posedge s_dram_clk) begin
        if(s_dram_rst) begin
            s_wr_ptr <= '0;
            s_trig <= '0;
        end else begin
            if (s_trig & s_wr_valid) begin
                s_trig <= 1'b0;
                case (s_wr_data[1:0])
                    2'b11: begin //new frame and new line
                        s_wr_ptr <= '0;
                    end
                    // 2'b01: begin //only new line
                    // end
                    default: begin //the rest
                        s_wr_ptr <= s_wr_ptr + 1'b1;
                    end
                endcase
            end
            if (s_wr_req_valid & s_wr_req_ready) begin
                s_trig <= 1'b1;
            end 
        end
    end

    `ifndef SIMULATION
    //--------------------------------------------------------------------------------
    // Read Request
    //--------------------------------------------------------------------------------

    logic                    s_rd_req_valid;
    logic [c_req_addrw-1:0]  s_rd_req_addr;
    logic                    s_rd_req_ready;
    mu_fifo_sync_reg #(
        .DW(c_req_addrw),
        .DEPTH(128)
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
    logic [p_dram_dataw-1:0]  s_debug_data;
    sdram_ctrl #(
        .ClockFreq(p_clock_feq),
        .BurstLength(8)
        // .BankWidth(c_bankw), 
        // .RowWidth(c_roww),
        // .ColWidth(c_colw)
    ) sdram_ctrl (
        .i_sys_clk(s_dram_clk),
        .i_dram_clk(s_dram_clk),
        .i_rst_n(~s_dram_rst),

        .o_ready(s_dram_ready),

        .i_wr_req  (s_wr_req_valid),
        // .i_wr_req  (0),
        .i_wr_addr (s_wr_req_addr), // TODO: update
        // .i_wr_addr ({8'd3,13'b0}), // TODO: update
        // .i_wr_addr (128'b0), // TODO: update
        .i_wr_data (s_wr_req_data),
        .o_wr_ready(s_wr_req_ready),

        .i_rd_req (s_rd_req_valid),
        .i_rd_addr(s_rd_req_addr),
        .o_rd_ready(s_rd_req_ready),

        .o_rd_valid (s_rd_dram_valid),
        .o_rd_data (s_rd_dram_data),

        .o_debug(s_debug),
        .o_debug_addr(s_debug_data),

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

    // assign o_debug_status = {o_dram_addr>>3,s_debug, s_dram_ready, s_dram_clk, s_wr_req_valid};
    // assign o_debug_status = {o_dram_addr>>0,s_debug, s_dram_ready, s_dram_clk, s_rd_req_valid};
    // assign o_debug_status = {o_dram_addr>>3,s_debug, s_new_line_sync};
    // assign o_debug_status = {s_rd_req_addr,s_rd_req_valid, s_rd_req_ready, s_dram_clk, s_new_line_sync};
    // assign o_debug_status = {s_debug_data,s_debug, s_dram_clk, s_new_line_sync};
    // assign o_debug_status = {s_rd_req_addr, s_rd_req_valid,s_debug, s_dram_ready, s_new_line_sync};
    // assign o_debug_status = {s_debug_data,s_debug, s_dram_ready, s_dram_clk, s_wr_req_valid};
    // assign o_debug_status = {s_rd_dram_valid,s_rd_req_ready, s_dram_ready,s_dram_clk, s_new_line_sync};
    // assign o_debug_status = {s_rd_dram_data,s_rd_dram_valid,s_dram_clk, s_new_line_sync};
    // assign o_debug_status = {s_rd_dram_valid,s_rd_req_ready, s_dram_ready,s_dram_clk, s_wr_req_valid|i_wr_fifo_valid};
    // assign o_debug_status = {s_wr_ready,s_wr_valid, s_dram_ready,s_dram_clk, s_wr_req_ready,s_wr_req_valid, s_wr_req_valid|s_wr_valid};
    // assign o_debug_status = {s_wr_req_data[0], s_wr_req_valid};
    // assign o_debug_status = {io_dram_data,s_dram_ready, s_rd_req_valid};
    // assign o_debug_status = {s_rd_dram_data, s_rd_dram_valid, s_new_line_sync};
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
        // .wr_used    (s_fill),

        .rd_clk     (i_clk_rd_fifo),
        .rd_nreset  (~i_rst),
        .rd_valid   (o_rd_fifo_valid),
        .rd_dout    (o_rd_fifo_data),
        .rd_ready   (i_rd_fifo_ready)
        // .rd_used    (s_rfill)
    );

    // cdc_fifo_gray #(
    //     .WIDTH(p_dram_dataw),
    //     .LOG_DEPTH(512*2)
    // ) inst_sdram_rd_fifo (
    //     .src_clk_i  (s_dram_clk),
    //     .src_rst_ni (~i_rst),
    //     .src_valid_i(s_rd_dram_valid),
    //     .src_data_i (s_rd_dram_data),
    //     .src_ready_o(s_rd_data_ready),
    //
    //     .dst_clk_i  (i_clk_rd_fifo),
    //     .dst_rst_ni (~i_rst),
    //     .dst_valid_o(o_rd_fifo_valid),
    //     .dst_data_o (o_rd_fifo_data),
    //     .dst_ready_i (i_rd_fifo_ready)
    // );
    // assign o_debug_status = {s_fill,s_dram_clk, s_rd_dram_valid|s_rd_req_valid};
    // assign o_debug_status = {s_rfill,s_dram_clk, s_rd_dram_valid|s_rd_req_valid};
    // assign o_debug_status = {s_rd_dram_data,s_dram_clk, s_rd_dram_valid|s_rd_req_valid};
    // assign o_debug_status = {s_rd_req_ready, s_rd_req_valid,i_rd_fifo_ready, o_rd_fifo_valid,s_load_rd_req_valid, s_load_rd_req_ready, s_dram_ready, s_new_line_sync, s_new_frame_sync};

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
    `endif
endmodule


