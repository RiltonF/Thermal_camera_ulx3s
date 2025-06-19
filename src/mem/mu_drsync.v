`timescale 1ns / 1ps
`default_nettype none
//
// mu_drsync.v: Synchronizer with async reset
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
module mu_drsync (
    input  wire clk,    // clock
    input  wire in,     // input data
    input  wire nreset, // async active low reset
    output wire out     // synchronized data
);

    localparam STAGES = 2;

    reg [STAGES-1:0] shiftreg;

    always @(posedge clk or negedge nreset)
        if (!nreset) shiftreg[STAGES-1:0] <= 'b0;
        else shiftreg[STAGES-1:0] <= {shiftreg[STAGES-2:0], in};

    assign out = shiftreg[STAGES-1];

endmodule

`default_nettype wire
