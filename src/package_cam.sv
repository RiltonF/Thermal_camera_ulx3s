`default_nettype none
`timescale 1ns / 1ps
package package_cam;

    typedef struct packed {
    logic sda; 
    logic scl;
    logic vsync;
    logic href;
    logic clk_pixel;
    logic clk_in;
    logic [7:0] data;
    logic rst;
    logic power_down;
    } t_cam_signals;

endpackage
