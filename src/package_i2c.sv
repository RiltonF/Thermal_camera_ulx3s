`default_nettype none
`timescale 1ns / 1ps

package package_i2c;
    typedef enum {
        NONE=0, START=1, BYTE=2, STOP=3
    } t_gen_states;
endpackage
