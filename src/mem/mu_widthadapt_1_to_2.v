`timescale 1ns / 1ps
`default_nettype none
//
// mu_widthadapt_1_to_2.v: Width adapter 1:2
// Adapted with word swapping by RiltonF
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
module mu_widthadapt_1_to_2 #(
    parameter IW = 32,
    parameter OW = IW * 2,
    parameter SWAP = 0
) (
    input  wire             clk,
    input  wire             rst,
    // Incoming port
    input  wire [IW-1:0]    wr_data,
    input  wire             wr_valid,
    output wire             wr_ready,
    // Outgoing port
    output wire [OW-1:0]    rd_data,
    output wire             rd_valid,
    input  wire             rd_ready
);

    reg [OW-1:0] fifo;
    reg fifo_full;
    reg fifo_empty;
    always @(posedge clk) begin
        if (fifo_empty) begin
            // Output invalid, if with valid input, fill input
            if (wr_valid) begin
                fifo <= (SWAP) ? {{IW{1'b0}}, wr_data} : {wr_data, {IW{1'b0}}};
                fifo_empty <= 1'b0;
                fifo_full <= 1'b0;
            end
        end
        else if (fifo_full) begin
            // Output valid, input not ready, if with valid output, shift
            if (rd_ready && wr_valid) begin
                fifo <= (SWAP) ? {{IW{1'b0}}, wr_data} : {wr_data, {IW{1'b0}}};
                fifo_empty <= 1'b0;
                fifo_full <= 1'b0;
            end
            else if (rd_ready) begin
                fifo_full <= 1'b0;
                fifo_empty <= 1'b1;
            end
        end
        else begin
            // Half empty, output not valid, input ready
            if (wr_valid) begin
                fifo <= (SWAP) ? {wr_data, fifo[IW+:IW]} : {fifo[IW+:IW], wr_data};
                fifo_full <= 1'b1;
                fifo_empty <= 1'b0;
            end
        end

        if (rst) begin
            fifo_full <= 1'b0;
            fifo_empty <= 1'b1;
        end
    end

    // RX data if fifo is empty
    assign wr_ready = !fifo_full || (fifo_full && rd_ready);
    assign rd_valid = fifo_full;
    assign rd_data = fifo;

endmodule

`default_nettype wire
