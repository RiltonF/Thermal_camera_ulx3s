`default_nettype none
`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
// Convert 8 bit data to 10bit tmds
// out = 8 bits of data, 1 bit encoding, 1 bit inverted symbol
// Xor or xnor is used to reduce the number of bit flips in the data to
// prevent noise and cross talk. Depending on the number of 1s in the data, an
// xor or xnor formula is used.
module tmds_gen (
    input  logic i_clk,
    input  logic i_rst,
    input  logic [7:0] i_data,
    input  logic [1:0] i_control_data, //[0] = hsync, [1] = vsync
    input  logic i_blanking,
    output logic [9:0] o_encoded
);
    typedef struct packed {
        logic [9:0] encoded;
        logic [$clog2(8):0] dc_bal_acc;
    } t_signals;


    // localparam t_signals c_reset = '{default: '0};
    localparam t_signals c_reset = '0;

    t_signals s_r, s_r_next;

    //signals for simulation
    logic [9:0] s_encoded;
    logic [$clog2(8):0] s_dc_bal_acc;
    assign s_encoded = s_r.encoded;
    assign s_dc_bal_acc = s_r.dc_bal_acc;

    always_comb begin
        logic [$clog2(8):0] v_ones_count;
        logic [$clog2(8):0] v_word_disparity;
        logic [8:0] v_xored_data, v_xnored_data;
        logic [8:0] v_data_word;
        logic v_is_xored;
        

        //initial assignment
        s_r_next = s_r;

        //count ones in the data
        v_ones_count = '0;
        for (int x = 0; x < $bits(i_data); x++)
            v_ones_count += i_data[x];

        //xored data
        v_xored_data[0] = i_data[0];
        for (int i = 1; i < 8; i++)
            v_xored_data[i] = v_xored_data[i-1] ^ i_data[i];
        v_xored_data[8] = 1'b1; //xors represented with 1

        //xnored data
        v_xnored_data[0] = i_data[0];
        for (int i = 1; i < 8; i++)
            v_xnored_data[i] = v_xnored_data[i-1] ~^ i_data[i];
        v_xnored_data[8] = 1'b0; //xnors represented with 0

        //XOR if less than 4 ones, or 4 ones and first bit is 1
        v_is_xored = (v_ones_count < 4) | ((v_ones_count == 4) & i_data[0]);
        v_data_word = (v_is_xored) ? v_xored_data : v_xnored_data;


        //count again the number of ones after xor/xnor-ing
        v_word_disparity = 'b1100; // = -4
        for (int x = 0; x < 8; x++)
            v_word_disparity += v_data_word[x];

        if (i_blanking) begin
            //lookup table for what to send during blanking period
            case(i_control_data)
                2'b00: s_r_next.encoded = 'b1101010100;
                2'b01: s_r_next.encoded = 'b0010101011;
                2'b10: s_r_next.encoded = 'b0101010100;
                2'b11: s_r_next.encoded = 'b1010101011;
            endcase
            //reset the dc ballance accumulator counter
            s_r_next.dc_bal_acc = '0;
        end else begin
            if (s_r.dc_bal_acc == '0 || v_word_disparity == '0) begin
                if (v_data_word[8]) begin
                    s_r_next.encoded = {~v_data_word[8], v_data_word[8], v_data_word[7:0]};
                    s_r_next.dc_bal_acc = s_r.dc_bal_acc + v_word_disparity;
                end else begin
                    s_r_next.encoded = {~v_data_word[8], v_data_word[8], ~v_data_word[7:0]};
                    s_r_next.dc_bal_acc = s_r.dc_bal_acc - v_word_disparity;
                end
            end
            //if the signs equal on both
            else if (s_r.dc_bal_acc[3] == v_word_disparity[3]) begin
                s_r_next.encoded = { 1'b1, v_data_word[8], ~v_data_word[7:0]};
                s_r_next.dc_bal_acc = s_r.dc_bal_acc + {'0,v_data_word[8]} - v_word_disparity;
            end
            //not equal, signs
            else begin
                s_r_next.encoded = { 1'b0, v_data_word[8], v_data_word[7:0]};
                s_r_next.dc_bal_acc = s_r.dc_bal_acc - {'0,~v_data_word[8]} + v_word_disparity;
            end
        end

        //output assignments
        o_encoded = s_r.encoded;
    end

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            s_r <= c_reset;
        end else begin
            s_r <= s_r_next;
        end
    end
endmodule


