`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
import package_i2c::BURST_WIDTH;
import package_i2c::BURST_WIDTH_16b;
import package_i2c::t_gen_states;
import package_i2c::NONE;
import package_i2c::START;
import package_i2c::BYTE;
import package_i2c::STOP;

module i2c_master #(
    // parameter int BURST_WIDTH = 4,
    parameter int CLK_FREQ = 25_000_000,
    parameter int I2C_FREQ = 100_000,
    parameter bit MODE_16BIT = 0,
    localparam int c_addr_w = (MODE_16BIT) ? 16 : 8,
    localparam int c_data_w = (MODE_16BIT) ? 16 : 8,
    localparam int c_burst_w =
        (MODE_16BIT) ? BURST_WIDTH_16b : BURST_WIDTH

) (
    input  logic i_clk,
    input  logic i_rst,

    //I2C master enable
    input  logic i_enable,

    //From CMD FIFO
    input  logic i_valid,
    input  logic i_we,
    input  logic i_sccb_mode,
    input  logic [6:0] i_addr_slave,
    input  logic [c_addr_w-1:0] i_addr_reg,
    input  logic [c_burst_w-1:0] i_burst_num,
    output logic o_ready,

    output logic o_cmd_ack,

    //From Write Data FIFO
    input  logic                i_wr_fifo_valid,
    input  logic [c_data_w-1:0] i_wr_fifo_data,
    output logic                o_wr_fifo_ready,

    //From Read Data FIFO
    output logic       o_rd_fifo_valid,
    output logic [7:0] o_rd_fifo_data,
    input  logic       i_rd_fifo_ready,

    //I2C Clock and Data lines
    inout logic b_sda,
    inout logic b_scl
);
    //byte_gen
    logic s_byte_req_ready;
    logic s_byte_wr_ack;
    logic s_byte_wr_nack;
    logic s_byte_rd_valid;
    assign s_byte_rd_valid = o_rd_fifo_valid;

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            o_cmd_ack <= '0;
        end else begin
            if (s_byte_wr_ack | s_byte_wr_nack) begin
                o_cmd_ack <= s_byte_wr_ack;
            end
        end
    end

    //start_gen & stop_gen
    logic        s_start_ready;
    logic        s_start_done;
    logic        s_stop_ready;
    logic        s_stop_done;

    //Gen state control signals
    t_gen_states s_active_gen;
    t_gen_states s_active_gen_next;

    //Req manager requests out
    logic        s_req_valid;
    logic        s_req_we;
    logic        s_req_last_byte;
    logic [7:0]  s_req_wr_byte;

    //Enables for generators, [0]=Start, [1]=BYTE, [2]=STOP
    logic [2:0]  s_gen_enables;
    logic [2:0]  s_gen_requests;

    //I2C drive signals from generators
    logic s_sda_drive,           s_scl_drive;
    logic s_start_gen_sda_drive, s_start_gen_scl_drive;
    logic s_bit_gen_sda_drive,   s_bit_gen_scl_drive;
    logic s_stop_gen_sda_drive,  s_stop_gen_scl_drive;

    assign b_sda = s_sda_drive ? 1'bz : 1'b0;
    assign b_scl = s_scl_drive ? 1'bz : 1'b0;

    always_comb begin : i2c_arbiter_switcher
        //SDA and SCL drivers
        case(s_active_gen)
            START: begin
                s_sda_drive = s_start_gen_sda_drive;
                s_scl_drive = s_start_gen_scl_drive;
            end
            BYTE: begin
                //Byte gen doesn't control the i2c lines,
                //bit gen does
                s_sda_drive = s_bit_gen_sda_drive;
                s_scl_drive = s_bit_gen_scl_drive;
            end
            STOP: begin
                s_sda_drive = s_stop_gen_sda_drive;
                s_scl_drive = s_stop_gen_scl_drive;
            end
            default: begin
                s_sda_drive = 1'b1; //high impedence
                s_scl_drive = 1'b1; //high impedence
            end
        endcase
        //Only one generator can be enables at a given time.
        case(s_active_gen_next)
            START: s_gen_enables = 3'b001;
            BYTE:  s_gen_enables = 3'b010;
            STOP:  s_gen_enables = 3'b100;
            default: s_gen_enables = 3'b0;
        endcase
        //Only one generator can get a request at a given time.
        if (s_req_valid) begin
            case(s_active_gen)
                START: s_gen_requests = 3'b001;
                BYTE:  s_gen_requests = 3'b010;
                STOP:  s_gen_requests = 3'b100;
                default: s_gen_requests = 3'b0;
            endcase
        end else begin
            s_gen_requests = 3'b0;
        end
    end

    generate
    if (MODE_16BIT) begin : gen_16bit_i2c_req_manager
        i2c_req_manager_16bit #(
            .BURST_WIDTH (c_burst_w)
        ) inst_i2c_req_manager (
            .i_clk             (i_clk),
            .i_rst             (i_rst),
            .i_enable          (i_enable),
            .i_valid           (i_valid),
            .i_we              (i_we),
            .i_sccb_mode       (i_sccb_mode),
            .i_addr_slave      (i_addr_slave),
            .i_addr_reg        (i_addr_reg),
            .i_burst_num       (i_burst_num),

            .o_ready           (o_ready),

            .i_valid_wr_byte   (i_wr_fifo_valid),
            .i_wr_byte         (i_wr_fifo_data),
            .o_ready_wr_byte   (o_wr_fifo_ready),

            .i_ready_rd_byte   (i_rd_fifo_ready),

            .i_byte_ready      (s_byte_req_ready),
            .i_wr_ack          (s_byte_wr_ack),
            .i_wr_nack         (s_byte_wr_nack),
            .i_rd_valid        (s_byte_rd_valid),

            .i_start_ready     (s_start_ready),
            .i_start_done      (s_start_done),
            .i_stop_ready      (s_stop_ready),
            .i_stop_done       (s_stop_done),

            .o_active_gen      (s_active_gen),
            .o_active_gen_next (s_active_gen_next),

            .o_req_valid       (s_req_valid),
            .o_req_we          (s_req_we),
            .o_req_last_byte   (s_req_last_byte),
            .o_wr_byte         (s_req_wr_byte)
        );
    end else begin : gen_8bit_i2c_req_manager
        i2c_req_manager_8bit #(
            .BURST_WIDTH (c_burst_w)
        ) inst_i2c_req_manager (
            .i_clk             (i_clk),
            .i_rst             (i_rst),
            .i_enable          (i_enable),
            .i_valid           (i_valid),
            .i_we              (i_we),
            .i_sccb_mode       (i_sccb_mode),
            .i_addr_slave      (i_addr_slave),
            .i_addr_reg        (i_addr_reg),
            .i_burst_num       (i_burst_num),

            .o_ready           (o_ready),

            .i_valid_wr_byte   (i_wr_fifo_valid),
            .i_wr_byte         (i_wr_fifo_data),
            .o_ready_wr_byte   (o_wr_fifo_ready),

            .i_ready_rd_byte   (i_rd_fifo_ready),

            .i_byte_ready      (s_byte_req_ready),
            .i_wr_ack          (s_byte_wr_ack),
            .i_wr_nack         (s_byte_wr_nack),
            .i_rd_valid        (s_byte_rd_valid),

            .i_start_ready     (s_start_ready),
            .i_start_done      (s_start_done),
            .i_stop_ready      (s_stop_ready),
            .i_stop_done       (s_stop_done),

            .o_active_gen      (s_active_gen),
            .o_active_gen_next (s_active_gen_next),

            .o_req_valid       (s_req_valid),
            .o_req_we          (s_req_we),
            .o_req_last_byte   (s_req_last_byte),
            .o_wr_byte         (s_req_wr_byte)
        );
    end
    endgenerate

    i2c_start_gen #(
        .CLK_FREQ (CLK_FREQ),
        .I2C_FREQ (I2C_FREQ)
    ) inst_i2c_start_gen (
        .i_clk       (i_clk),
        .i_rst       (i_rst),
        .i_req       (s_gen_requests[0]),
        .i_enable    (s_gen_enables[0]),
        .o_done      (s_start_done),
        .o_ready     (s_start_ready),
        .i_sda       (b_sda),
        .i_scl       (b_scl),
        .o_sda_drive (s_start_gen_sda_drive),
        .o_scl_drive (s_start_gen_scl_drive)
    );

    logic s_byte_bit_req;
    logic s_byte_bit_we;
    logic s_byte_bit_wr_bit;
    logic s_byte_bit_ready;
    logic s_byte_bit_rd_valid;
    logic s_byte_bit_rd_bit;
    i2c_byte_gen inst_i2c_byte_gen (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_req          (s_gen_requests[1]),
        .i_we           (s_req_we),
        .i_wr_byte      (s_req_wr_byte),
        .i_rd_last      (s_req_last_byte),
        .o_ready        (s_byte_req_ready),
        .o_wr_ack       (s_byte_wr_ack),
        .o_wr_nack      (s_byte_wr_nack),
        .o_rd_valid     (o_rd_fifo_valid),
        .o_rd_byte      (o_rd_fifo_data),
        .o_req_bit      (s_byte_bit_req),
        .o_we_bit       (s_byte_bit_we),
        .o_wr_bit       (s_byte_bit_wr_bit),
        .i_ready_bit    (s_byte_bit_ready),
        .i_rd_valid_bit (s_byte_bit_rd_valid),
        .i_rd_bit       (s_byte_bit_rd_bit)
    );
    i2c_bit_gen #(
        .CLK_FREQ (CLK_FREQ),
        .I2C_FREQ (I2C_FREQ)
    ) inst_i2c_bit_gen (
        .i_clk       (i_clk),
        .i_rst       (i_rst),
        .i_enable    (s_gen_enables[1]),
        .i_req       (s_byte_bit_req),
        .i_we        (s_byte_bit_we),
        .i_wr_bit    (s_byte_bit_wr_bit),
        .o_ready     (s_byte_bit_ready),
        .o_rd_valid  (s_byte_bit_rd_valid),
        .o_rd_bit    (s_byte_bit_rd_bit),
        .i_sda       (b_sda),
        .i_scl       (b_scl),
        .o_sda_drive (s_bit_gen_sda_drive),
        .o_scl_drive (s_bit_gen_scl_drive)
    );

    i2c_stop_gen #(
        .CLK_FREQ (CLK_FREQ),
        .I2C_FREQ (I2C_FREQ)
    ) inst_i2c_stop_gen (
        .i_clk       (i_clk),
        .i_rst       (i_rst),
        .i_req       (s_gen_requests[2]),
        .i_enable    (s_gen_enables[2]),
        .o_done      (s_stop_done),
        .o_ready     (s_stop_ready),
        .i_sda       (b_sda),
        .i_scl       (b_scl),
        .o_sda_drive (s_stop_gen_sda_drive),
        .o_scl_drive (s_stop_gen_scl_drive)
    );
endmodule
