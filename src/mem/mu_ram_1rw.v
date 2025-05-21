`timescale 1ns / 1ps
`default_nettype none
//
// mu_ram_1rw.v: Simple single port RAM model
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

module mu_ram_1rw #(
    parameter DW = 8,
    parameter AW = 12
) (
    input wire clk,
    // Read port
    input wire [AW-1:0] addr,
    output wire [DW-1:0] rd,
    input wire [DW-1:0] wr,
    input wire we
);

    localparam DEPTH = (1 << AW);

    reg [DW-1:0] mem [0:DEPTH-1];
    reg [DW-1:0] rd_reg;

    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= wr;
        end
        else if (re) begin
            rd_reg <= mem[addr];
        end
    end

    assign rd = rd_reg;

endmodule

`default_nettype wire
