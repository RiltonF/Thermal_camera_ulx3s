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
module mu_fifo_sync_reg #(
    parameter DW = 64,
    parameter DEPTH = 4
) (
    input  wire             clk,
    input  wire             rst,

    input  wire [DW-1:0]    wr_data,
    input  wire             wr_valid,
    output wire             wr_ready,

    output reg [DW-1:0]     rd_data,
    output reg              rd_valid,
    input  wire             rd_ready
);
    wire             fifo_valid;
    wire[DW-1:0]     fifo_data;
    wire             fifo_ready;

    wire load = (!rd_valid || rd_ready) && fifo_valid;

    assign fifo_ready = load;

    always @(posedge clk) begin
        if (rst) begin
            rd_valid <= 0;
            rd_data  <= '0;
        end else if (load) begin
            rd_valid <= 1;
            rd_data  <= fifo_data;
        end else if (rd_ready && rd_valid) begin
            rd_valid <= 0;
        end
    end

    mu_fifo_sync #(
        .DW(DW),
        .DEPTH(DEPTH)
    ) inst_read_req_fifo (
        .clk,
        .rst,

        .wr_valid,
        .wr_data,
        .wr_ready,

        .rd_valid (fifo_valid),
        .rd_data  (fifo_data),
        .rd_ready (fifo_ready)
    );
    endmodule

`default_nettype wire
