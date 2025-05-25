`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
import package_i2c::t_i2c_cmd_16b;

module i2c_master_wrapper_16b #(
    parameter bit CMD_FIFO = 1'b1,
    parameter bit WR_FIFO = 1'b1,
    parameter bit RD_FIFO = 1'b1
)(
    input  logic i_clk,
    input  logic i_rst,

    input logic i_enable,

    //CMD interface
    input  logic         i_cmd_fifo_valid,
    input  t_i2c_cmd_16b i_cmd_fifo_data,
    output logic         o_cmd_fifo_ready,

    //WR Data interface
    input  logic        i_wr_fifo_valid,
    input  logic [15:0] i_wr_fifo_data,
    output logic        o_wr_fifo_ready,

    //RD Data interface
    output logic       o_rd_fifo_valid,
    output logic [7:0] o_rd_fifo_data,
    input  logic       i_rd_fifo_ready,

    //I2C Clock and Data lines
    inout logic b_sda,
    inout logic b_scl
);
    localparam int CLK_FREQ = 25_000_000;
    localparam int I2C_FREQ = 100_000;

    // CMD FIFO
    logic s_cmd_valid, s_cmd_ready;
    t_i2c_cmd_16b s_cmd_data;
    generate
    if (CMD_FIFO) begin : gen_cmd_fifo
        mu_fifo_sync #(
            .DW($bits(i_cmd_fifo_data)),
            .DEPTH(16)
        ) inst_cmd_fifo (
            .clk            (i_clk),
            .rst            (i_rst),
            .wr_valid       (i_cmd_fifo_valid),
            .wr_data        (i_cmd_fifo_data),
            .wr_ready       (o_cmd_fifo_ready),
            .wr_almost_full (),
            .wr_full        (),
            .rd_valid       (s_cmd_valid),
            .rd_data        (s_cmd_data),
            .rd_ready       (s_cmd_ready)
        );
    end else begin : gen_cmd_assign
        assign s_cmd_valid = i_cmd_fifo_valid;
        assign s_cmd_data = i_cmd_fifo_data;
        assign o_cmd_fifo_ready = s_cmd_ready;
    end
    endgenerate

    // WRITE FIFO
    logic s_write_valid, s_write_ready;
    logic [15:0] s_write_data;
    generate
    if (WR_FIFO) begin : gen_wr_fifo
        mu_fifo_sync #(
            .DW($bits(i_wr_fifo_data)),
            .DEPTH(16)
        ) inst_write_fifo (
            .clk            (i_clk),
            .rst            (i_rst),
            .wr_valid       (i_wr_fifo_valid),
            .wr_data        (i_wr_fifo_data),
            .wr_ready       (o_wr_fifo_ready),
            .wr_almost_full (),
            .wr_full        (),
            .rd_valid       (s_write_valid),
            .rd_data        (s_write_data),
            .rd_ready       (s_write_ready)
        );
    end else begin : gen_wr_assign
        assign s_write_valid = i_wr_fifo_valid;
        assign s_write_data = i_wr_fifo_data;
        assign o_wr_fifo_ready = s_write_ready;
    end
    endgenerate

    // READ FIFO
    logic s_read_valid, s_read_ready;
    logic [7:0] s_read_data;
    generate
    if (RD_FIFO) begin : gen_rd_fifo
        mu_fifo_sync #(
            .DW($bits(o_rd_fifo_data)),
            .DEPTH(16)
        ) inst_read_fifo (
            .clk            (i_clk),
            .rst            (i_rst),
            .wr_valid       (s_read_valid),
            .wr_data        (s_read_data),
            .wr_ready       (s_read_ready),
            .wr_almost_full (),
            .wr_full        (),
            .rd_valid       (o_rd_fifo_valid),
            .rd_data        (o_rd_fifo_data),
            .rd_ready       (i_rd_fifo_ready)
        );
    end else begin : gen_rd_assign
        assign o_rd_fifo_valid = s_read_valid;
        assign o_rd_fifo_data = s_read_data;
        assign s_read_ready = i_rd_fifo_ready;
    end
    endgenerate

    i2c_master #(
        // .BURST_WIDTH (BURST_WIDTH_16b),
        .CLK_FREQ    (CLK_FREQ),
        .I2C_FREQ    (I2C_FREQ),
        .MODE_16BIT  (1'b1)
    ) inst_i2c_master (
        .i_clk           (i_clk),
        .i_rst           (i_rst),
        .i_enable        (i_enable),
        .i_valid         (s_cmd_valid),
        .i_we            (s_cmd_data.we),
        .i_sccb_mode     (s_cmd_data.sccb_mode),
        .i_addr_slave    (s_cmd_data.addr_slave),
        .i_addr_reg      (s_cmd_data.addr_reg),
        .i_burst_num     (s_cmd_data.burst_num),
        .o_ready         (s_cmd_ready),
        .i_wr_fifo_valid (s_write_valid),
        .i_wr_fifo_data  (s_write_data),
        .o_wr_fifo_ready (s_write_ready),
        .o_rd_fifo_valid (s_read_valid),
        .o_rd_fifo_data  (s_read_data),
        .i_rd_fifo_ready (s_read_ready),
        .b_sda(b_sda),
        .b_scl(b_scl)
    );
endmodule


