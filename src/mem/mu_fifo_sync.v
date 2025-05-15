`timescale 1ns / 1ps
`default_nettype none
//
// mu_fifo_sync.v: Sync FIFO
//
// Copyright 2024 Wenting Zhang <zephray@outlook.com>
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
module mu_fifo_sync #(
    parameter DW = 64,
    parameter DEPTH = 4
) (
    input  wire             clk,
    input  wire             rst,
    input  wire [DW-1:0]    wr_data,
    input  wire             wr_valid,
    output wire             wr_ready,
    output wire             wr_almost_full,
    output wire             wr_full,
    output wire [DW-1:0]    rd_data,
    output wire             rd_valid,
    input  wire             rd_ready
);

    localparam AW = $clog2(DEPTH);

    reg [DW-1:0] fifo [0:DEPTH-1];
    reg [AW:0] fifo_level;
    reg [AW-1:0] wr_ptr;
    reg [AW-1:0] rd_ptr;

    wire wr_active = wr_ready && wr_valid;
    wire rd_active = rd_ready && rd_valid;

    wire fifo_empty = fifo_level == 0;
    wire fifo_almost_full = fifo_level == DEPTH - 1;
    wire fifo_full = fifo_level == DEPTH;

    always @(posedge clk) begin
        if (wr_ready && wr_valid)
            fifo[wr_ptr] <= wr_data;
        if (wr_active && !rd_active)
            fifo_level <= fifo_level + 1;
        else if (!wr_active && rd_active)
            fifo_level <= fifo_level - 1;
        if (wr_active)
            wr_ptr <= wr_ptr + 1;
        if (rd_active)
            rd_ptr <= rd_ptr + 1;

        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            fifo_level <= 0;
        end
    end
    assign rd_valid = !fifo_empty;
    assign rd_data = fifo[rd_ptr];
    assign wr_ready = !fifo_almost_full;
    assign wr_almost_full = fifo_almost_full;
    assign wr_full = fifo_full;

endmodule

`default_nettype wire
