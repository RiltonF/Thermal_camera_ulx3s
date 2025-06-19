`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */

module sdram_top #(
    parameter int p_sdram_dataw = 16,
    parameter int p_sdram_rows = 8192,
    parameter int p_sdram_banks= 4,
    localparam int c_addrw = $clog2(p_sdram_rows),
    localparam int c_bankw = $clog2(p_sdram_banks)
) (
    input  logic i_clk, //25MHz clock
    input  logic i_rst,

    input  logic                     i_clk_wr_fifo, //pixel clock from camera
    input  logic                     i_wr_fifo_valid,
    input  logic [p_sdram_dataw-1:0] i_wr_fifo_data,
    output logic                     o_wr_fifo_ready,

    output logic                     o_rd_fifo_valid,
    output logic [p_sdram_dataw-1:0] o_rd_fifo_data,
    input  logic                     i_rd_fifo_ready,

    //controller to sdram
    output logic                     o_sdram_clk, //180 deg shifted clock
    output logic                     o_sdram_cke,
    output logic                     o_sdram_cs_n,
    output logic                     o_sdram_we_n,
    output logic                     o_sdram_ras_n,
    output logic                     o_sdram_cas_n,
    output logic [      c_addrw-1:0] o_sdram_addr,
    output logic [      c_bankw-1:0] o_sdram_ba,
    output logic [              1:0] o_sdram_dqm,
    inout  wire  [p_sdram_dataw-1:0] b_sdram_dq,

    output logic                     o_sdram_initialized,

    input  logic [              1:0] i_debug_trig,
    output logic [              7:0] o_debug_status
);
    logic s_sdram_clk;
    logic s_sdram_rst;
    logic s_sdram_rd_clk;
    logic s_sdram_rd_rst;

    logic                     s_sdram_ready;

    logic                     s_wr_valid;
    logic [p_sdram_dataw-1:0] s_wr_data;
    logic                     s_wr_ready;
    logic                     s_wr_almost_empty;

    logic                     s_rd_valid;
    logic [p_sdram_dataw-1:0] s_rd_data;
    logic                     s_rd_ready;
    logic                     s_rd_almost_full;

    logic [3:0] s_fifo_debug_events;

    //A bit of a hacky way to generate requests based on fifo fill levels
    logic s_wr_req_valid;
    logic s_rd_req_valid;

    `ifdef SIMULATION
        assign s_wr_req_valid = i_debug_trig[0];
        assign s_rd_req_valid = i_debug_trig[1];
    `else
        // almost empty means fill_level <= threshold, if it's more than 512, we
        // send a write request
        assign s_wr_req_valid = s_wr_valid & ~s_wr_almost_empty;
        // almost full means fill_level >= threshold, if it's less than 512, we
        // send a read request
        assign s_rd_req_valid = ~s_rd_almost_full;
        // assign s_rd_req_valid = i_debug_trig[1];
    `endif

    // Full VGA frame / page size
    localparam int c_full_frame_words = 640*480;
    localparam int c_full_frame_pages = $rtoi($ceil(c_full_frame_words/512));
    localparam int c_countw = $clog2(c_full_frame_pages);
    typedef struct packed {
        logic                busy;
        logic                sdram_rw_en;
        logic                sdram_rw;
        logic [ c_addrw-1:0] sdram_addr;
        logic [ c_bankw-1:0] sdram_ba;
        logic [c_countw-1:0] read_row;
        logic [c_countw-1:0] write_row;
        logic                sdram_ready_latch;
    } t_signals;

    t_signals s_r, s_r_next;

    `ifndef SIMULATION
        localparam t_signals c_signals_reset = '{default:'0};
    `else
        localparam t_signals c_signals_reset = {'0};
        logic                d_busy;
        logic                d_sdram_rw_en;
        logic                d_sdram_rw;
        logic [c_countw-1:0] d_read_row;
        logic [c_countw-1:0] d_write_row;
        logic [ c_addrw-1:0] d_sdram_addr;
        assign d_busy = s_r.busy;
        assign d_read_row = s_r.read_row;
        assign d_write_row = s_r.write_row;
        assign d_sdram_addr = s_r.sdram_addr;
        assign d_sdram_rw = s_r.sdram_rw;
        assign d_sdram_rw_en = s_r.sdram_rw_en;
    `endif

    logic s_overflow_addr;

    always_comb begin
        //init
        s_r_next = s_r;

        s_r_next.sdram_ready_latch = s_sdram_ready;

        //debug
        // o_debug_status = {s_r_next.sdram_addr, s_r.busy, s_r.sdram_rw, s_r.sdram_rw_en, s_sdram_ready, s_overflow_addr};

        if (~s_r.busy) begin
            if (s_r.sdram_ready_latch & (s_wr_req_valid | s_rd_req_valid)) begin
                s_r_next.busy = 1'b1;
                s_r_next.sdram_rw_en = 1'b1;
                s_r_next.sdram_rw = s_rd_req_valid; //give priority to read if both are high
                s_r_next.sdram_addr = (s_r_next.sdram_rw) ?  s_r.read_row : s_r.write_row; //set row address
                s_r_next.sdram_ba = '0;
            end
        end else begin
            // s_r_next.sdram_addr = '0; //set col address, controller doesn't have any support for other columns...
            // s_r_next.sdram_rw_en = 1'b0; //Disable new req during operation
            // if (s_sdram_ready) begin
            if (s_r.sdram_ready_latch == 0) begin
                s_r_next.sdram_addr = '0; //set col address, controller doesn't have any support for other columns...
                s_r_next.sdram_rw_en = 1'b0; //Disable new req during operation
            end
            if ((s_sdram_ready == 1) & (s_r.sdram_ready_latch == 0)) begin
                s_r_next.busy = 1'b0;
                if (s_r.sdram_rw) begin
                    //Read request
                    s_r_next.read_row = (s_r_next.read_row >= c_full_frame_pages - 1) ? '0 : s_r_next.read_row + 1;
                end else begin
                    //Write request
                    s_r_next.write_row = (s_r_next.write_row >= c_full_frame_pages - 1 ) ? '0 : s_r_next.write_row + 1;
                end
            end
        end
    end

    always_ff @(posedge s_sdram_clk) begin
        if (s_sdram_rst) begin
            s_r <= c_signals_reset;
            s_overflow_addr <= '0;
            o_sdram_initialized <= '0;
        end else begin
            s_r <= s_r_next;
            if (s_r.sdram_addr >= 'd600) s_overflow_addr <= 1'b1;
            if (s_sdram_ready) o_sdram_initialized <= 1'b1;
        end
    end

    `ifndef SIMULATION
    // TODO: Move these debug events to the fifo module...
    logic s_debug_write_fifo_invalid_write;
    always_ff @(posedge i_clk_wr_fifo) begin
        if (i_rst) s_debug_write_fifo_invalid_write <= '0;
        //Write occured when the ready was low.
        else if (~o_wr_fifo_ready & i_wr_fifo_valid) s_debug_write_fifo_invalid_write <= 1'b1;
    end
    logic s_debug_write_fifo_invalid_read;
    always_ff @(posedge s_sdram_clk) begin
        //Read occured when the valid was low. (Might not be always an issue,
        //dependingon the connected interface request/valid or ready/valid
        if (s_sdram_rst) s_debug_write_fifo_invalid_read <= '0;
        else if (s_wr_ready & ~s_wr_valid) s_debug_write_fifo_invalid_read <= 1'b1;
    end
    mu_fifo_async #(
        .DW(p_sdram_dataw),
        .DEPTH(512*2),
        .THRESH_EMPTY(512)
    ) inst_sdram_wr_fifo (
        .wr_clk     (i_clk_wr_fifo),
        .wr_nreset  (~i_rst),
        .wr_valid   (i_wr_fifo_valid),
        .wr_din     (i_wr_fifo_data),
        .wr_ready   (o_wr_fifo_ready),
        .wr_almost_full (), //unused

        .rd_clk     (s_sdram_clk),
        .rd_nreset  (~s_sdram_rst),
        .rd_valid   (s_wr_valid),
        .rd_dout    (s_wr_data),
        .rd_ready   (s_wr_ready),
        .rd_almost_empty (s_wr_almost_empty)
    );
    // assign o_debug_status = {s_wr_valid,s_wr_ready,s_sdram_clk, ~s_wr_almost_empty, s_sdram_ready};
    // assign o_debug_status = {s_fifo_debug_events ,i_clk_wr_fifo,i_wr_fifo_valid, o_wr_fifo_ready};
    assign o_debug_status = {s_wr_data, s_wr_valid,s_wr_ready};

    // TODO: Move these debug events to the fifo module...
    logic s_debug_read_fifo_invalid_write;
    always_ff @(posedge s_sdram_rd_clk) begin
        if (s_sdram_rd_rst) s_debug_read_fifo_invalid_write <= '0;
        //Write occured when the ready was low.
        else if (~s_rd_ready & s_rd_valid) s_debug_read_fifo_invalid_write <= 1'b1;
    end
    logic s_debug_read_fifo_invalid_read;
    always_ff @(posedge i_clk) begin
        //Read occured when the valid was low. (Might not be always an issue,
        //dependingon the connected interface request/valid or ready/valid
        if (i_rst) s_debug_read_fifo_invalid_read <= '0;
        else if (i_rd_fifo_ready & ~o_rd_fifo_valid) s_debug_read_fifo_invalid_read <= 1'b1;
    end
    mu_fifo_async #(
        .DW(p_sdram_dataw),
        // .DEPTH(1) //testing
        .DEPTH(512*2),
        .THRESH_FULL(512-64)
    ) inst_sdram_rd_fifo (
        .wr_clk     (s_sdram_rd_clk),
        .wr_nreset  (~s_sdram_rd_rst),
        .wr_valid   (s_rd_valid),
        .wr_din     (s_rd_data),
        .wr_ready   (s_rd_ready), //no backpressure possible for the sdram read data
        .wr_almost_full (s_rd_almost_full),

        .rd_clk     (i_clk),
        .rd_nreset  (~i_rst),
        .rd_valid   (o_rd_fifo_valid),
        .rd_dout    (o_rd_fifo_data),
        .rd_ready   (i_rd_fifo_ready),
        .rd_almost_empty () //unused
    );

    assign s_fifo_debug_events = {
        s_debug_read_fifo_invalid_read,
        s_debug_read_fifo_invalid_write,
        s_debug_write_fifo_invalid_read,
        s_debug_write_fifo_invalid_write};

    // assign o_debug_status = s_fifo_debug_events;
    // assign o_debug_status = {s_rd_ready, s_rd_valid, s_sdram_rd_clk, i_rd_fifo_ready,o_rd_fifo_valid, i_clk, i_debug_trig[1]};

    sdram_controller inst_sdram_controller (
        //fpga to controller
        .clk            (s_sdram_clk), //clk=143MHz
        .rst_n          (~s_sdram_rst),
        .rw             (s_r.sdram_rw), // 1:read , 0:write
        .rw_en          (s_r.sdram_rw_en), //must be asserted before read/write
        .f_addr         ({s_r.sdram_addr, s_r.sdram_ba}), //14:2=row(13)  , 1:0=bank(2), col=0 on page bursts
        .f2s_data_valid (s_wr_ready), //this is actually a ready
        .f2s_data       (s_wr_data), //fpga-to-sdram data

        .s2f_data_valid (s_rd_valid),
        .s2f_data       (s_rd_data), //sdram to fpga data
        .ready          (s_sdram_ready), //"1" if sdram is available for nxt read/write operation

        //controller to sdram
        .s_clk          (o_sdram_clk), //180 shifted clock
        .s_cke          (o_sdram_cke),
        .s_cs_n         (o_sdram_cs_n),
        .s_ras_n        (o_sdram_ras_n ),
        .s_cas_n        (o_sdram_cas_n),
        .s_we_n         (o_sdram_we_n),
        .s_addr         (o_sdram_addr),
        .s_ba           (o_sdram_ba),
        .LDQM           (o_sdram_dqm[0]),
        .HDQM           (o_sdram_dqm[1]),
        .s_dq           (b_sdram_dq)
    );

    clk_sdram inst_clk_gen_ddr (
        .clkin(i_clk),
        .clkout0(s_sdram_clk), //142.857 MHz
        .clkout1(s_sdram_rd_clk), //142.857 MHz +90 deg shift
        .locked()
    );

    reset_sync inst_sdram_reset_sync (
        .i_clk(s_sdram_clk),
        .i_async_rst(i_rst),
        .o_rst(s_sdram_rst)
    );
    reset_sync inst_sdram_rd_reset_sync (
        .i_clk(s_sdram_rd_clk),
        .i_async_rst(i_rst),
        .o_rst(s_sdram_rd_rst)
    );
    `endif
endmodule


