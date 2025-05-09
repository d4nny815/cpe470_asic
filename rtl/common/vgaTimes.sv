`ifndef VGA_TIMES_H
`define VGA_TIMES_H

package vgaTimes;
    // http://www.tinyvga.com/vga-timing/640x480@60Hz
    localparam H_VISIBLE_AREA   = 640;
    localparam H_FRONTPORCH     = 18;
    localparam H_SYNC_PULSE     = 96;
    localparam H_BACKPORCH      = 480;
    localparam H_WHOLELINE      = 800;

    localparam V_VISIBLE_AREA   = 480;
    localparam V_FRONTPORCH     = 10;
    localparam V_SYNC_PULSE     = 2;
    localparam V_BACKPORCH      = 33;
    localparam V_WHOLELINE      = 525;

    localparam H_BITS = $clog2(H_WHOLELINE);
    localparam V_BITS = $clog2(V_WHOLELINE);
endpackage

`endif