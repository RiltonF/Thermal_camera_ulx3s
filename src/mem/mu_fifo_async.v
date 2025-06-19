`timescale 1ns / 1ps
`default_nettype none
//
// mu_fifo_async.v: Dual Clock Asynchronous FIFO
// Modified by RiltonF
//
// This file is adapted from the lambdalib project
// Copyright Lambda Project Authors. All rights Reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
module mu_fifo_async #(
    parameter DW = 32,        // Memory width
    parameter DEPTH = 4,      // FIFO depth
    parameter THRESH_FULL = DEPTH - 1,
    parameter THRESH_EMPTY = 1
) (  // write port
    input  wire             wr_clk,
    input  wire             wr_nreset,
    input  wire [DW-1:0]    wr_din,        // data to write
    input  wire             wr_valid,      // write fifo
    output wire             wr_ready,      // fifo not full
    output reg              wr_almost_full,
    // read port
    input  wire             rd_clk,
    input  wire             rd_nreset,
    output reg [DW-1:0]    rd_dout,       // output data (next cycle)
    input  wire             rd_ready,      // read fifo
    output reg              rd_valid,      // fifo is not empty
    output reg              rd_almost_empty
);

    // local params
    // The last part is to support DEPTH of 1
    localparam AW = $clog2(DEPTH) + {31'h0, (DEPTH == 1)};

    /* verilator lint_off UNUSEDSIGNAL */
    // local wires
    reg  [AW:0] wr_grayptr;
    reg  [AW:0] wr_binptr;
    reg  [AW:0] wr_binptr_mem;
    wire [AW:0] wr_grayptr_nxt;
    wire [AW:0] wr_binptr_nxt;
    wire [AW:0] wr_binptr_mem_nxt;
    wire [AW:0] wr_grayptr_sync;

    reg  [AW:0] rd_grayptr;
    reg  [AW:0] rd_binptr;
    reg  [AW:0] rd_binptr_mem;
    wire [AW:0] rd_grayptr_nxt;
    wire [AW:0] rd_binptr_nxt;
    wire [AW:0] rd_binptr_mem_nxt;
    wire [AW:0] rd_grayptr_sync;
    /* verilator lint_on UNUSEDSIGNAL */

    genvar i;

    //###########################
    //# WRITE SIDE LOGIC
    //###########################

    always @(posedge wr_clk or negedge wr_nreset)
        if (~wr_nreset) begin
            wr_binptr_mem[AW:0] <= 'b0;
            wr_binptr[AW:0]     <= 'b0;
            wr_grayptr[AW:0]    <= 'b0;
        end else begin
            wr_binptr_mem[AW:0] <= (wr_binptr_mem_nxt[AW:0] == DEPTH) ? 'b0 :
                wr_binptr_mem_nxt[AW:0];
            wr_binptr[AW:0] <= wr_binptr_nxt[AW:0];
            wr_grayptr[AW:0] <= wr_grayptr_nxt[AW:0];
        end

    // Update binary pointer on write and not full
    assign wr_binptr_mem_nxt[AW:0] = wr_binptr_mem[AW-1:0] +
        {{(AW-1){1'b0}}, (wr_valid && wr_ready)};
    assign wr_binptr_nxt[AW:0] = wr_binptr[AW:0] +
        {{AW{1'b0}}, (wr_valid && wr_ready)};

    // Convert binary point to gray pointer for sync
    assign wr_grayptr_nxt[AW:0] =
        wr_binptr_nxt[AW:0] ^ {1'b0, wr_binptr_nxt[AW:1]};

    // Full comparison (gray pointer based)
    // Amir - add support for fifo DEPTH that is not power of 2
    // Note - the previous logic also had a bug that full was high one entry to soon

    reg [AW:0] rd_binptr_sync;
    wire [AW:0] wr_fifo_used;
    integer j;

    always @(*) begin
        rd_binptr_sync[AW] = rd_grayptr_sync[AW];
        for (j = AW; j > 0; j = j - 1)
        rd_binptr_sync[j-1] = rd_binptr_sync[j] ^ rd_grayptr_sync[j-1];
    end

    assign wr_fifo_used = wr_binptr - rd_binptr_sync;
    assign wr_almost_full = wr_fifo_used >= THRESH_FULL;
    // always @(posedge wr_clk) wr_almost_full = wr_fifo_used >= THRESH_FULL;

    reg wr_full;

    always @(posedge wr_clk or negedge wr_nreset)
        if (~wr_nreset)
            wr_full <= 1'b0;
        else
            wr_full <= (wr_fifo_used + {{AW{1'b0}}, (wr_valid && ~wr_full)}) == DEPTH;
    assign wr_ready = !wr_full;

    // Write --> Read clock synchronizer
    for (i = 0; i < (AW + 1); i = i + 1) begin
        // (* keep *)
        mu_drsync wrsync (
            .out(wr_grayptr_sync[i]),
            .clk(rd_clk),
            .nreset(rd_nreset),
            .in(wr_grayptr[i])
        );
    end

    //###########################
    //# READ SIDE LOGIC
    //###########################

    always @(posedge rd_clk or negedge rd_nreset)
        if (~rd_nreset) begin
            rd_binptr_mem[AW:0] <= 'b0;
            rd_binptr[AW:0]     <= 'b0;
            rd_grayptr[AW:0]    <= 'b0;
        end else begin
            rd_binptr_mem[AW:0] <= (rd_binptr_mem_nxt[AW:0] == DEPTH) ? 'b0 :
                rd_binptr_mem_nxt[AW:0];
            rd_binptr[AW:0] <= rd_binptr_nxt[AW:0];
            rd_grayptr[AW:0] <= rd_grayptr_nxt[AW:0];
        end

    assign rd_binptr_mem_nxt[AW:0] =
        rd_binptr_mem[AW-1:0] + {{(AW-1){1'b0}}, (rd_ready && rd_valid)};
    assign rd_binptr_nxt[AW:0] =
        rd_binptr[AW:0] + {{AW{1'b0}}, (rd_ready && rd_valid)};
    assign rd_grayptr_nxt[AW:0] =
        rd_binptr_nxt[AW:0] ^ {1'b0, rd_binptr_nxt[AW:1]};

    // Full comparison (gray pointer based)
    always @(posedge rd_clk or negedge rd_nreset)
        if (~rd_nreset)
            rd_valid <= 1'b0;
        else
            rd_valid <= (rd_grayptr_nxt[AW:0] != wr_grayptr_sync[AW:0]);

    // Read --> write clock synchronizer
    for (i = 0; i < (AW + 1); i = i + 1) begin
        // (* keep *)
        mu_drsync rdsync (
            .out(rd_grayptr_sync[i]),
            .clk(wr_clk),
            .nreset(wr_nreset),
            .in(rd_grayptr[i])
        );
    end

    reg [AW:0] wr_binptr_sync;
    wire [AW:0] rd_fifo_used;
    integer k;

    always @(*) begin
        wr_binptr_sync[AW] = wr_grayptr_sync[AW];
        for (k = AW; k > 0; k = k - 1)
        wr_binptr_sync[k-1] = wr_binptr_sync[k] ^ wr_grayptr_sync[k-1];
    end

    assign rd_fifo_used = wr_binptr_sync - rd_binptr;
    assign rd_almost_empty = rd_fifo_used <= THRESH_EMPTY;

    //###########################
    //# Dual Port Memory
    //###########################

    reg [DW-1:0] ram [DEPTH-1:0];

    // Write port (FIFO input)
    always @(posedge wr_clk)
        if (wr_valid & ~wr_full)
            ram[wr_binptr_mem[AW-1:0]] <= wr_din[DW-1:0];

    always @(posedge rd_clk)
        rd_dout[DW-1:0] <= ram[rd_binptr_mem[AW-1:0]];
    // Read port (FIFO output)
    // assign rd_dout[DW-1:0] = ram[rd_binptr_mem[AW-1:0]];

endmodule

`default_nettype wire
