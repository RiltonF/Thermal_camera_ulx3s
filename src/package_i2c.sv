`default_nettype none
`timescale 1ns / 1ps

package package_i2c;
    typedef enum {
        NONE=0, START=1, BYTE=2, STOP=3
    } t_gen_states;

    localparam int BURST_WIDTH = 4;
    localparam int BURST_WIDTH_16b = 10;

    typedef struct packed {
        logic                   we;
        logic                   sccb_mode;
        logic             [6:0] addr_slave;
        logic             [7:0] addr_reg;
        logic [BURST_WIDTH-1:0] burst_num;
    } t_i2c_cmd;

    typedef struct packed {
        logic                       we;
        logic                       sccb_mode;
        logic                 [6:0] addr_slave;
        logic                [15:0] addr_reg;
        logic [BURST_WIDTH_16b-1:0] burst_num;
    } t_i2c_cmd_16b;

endpackage
