`ifndef VGA_TIMES_H
`define VGA_TIMES_H

package vgaTimes;
    // http://www.tinyvga.com/vga-timing/800x600@72Hz
    localparam H_VISIBLE_AREA   = 800;
    localparam H_FRONTPORCH     = 56;
    localparam H_SYNC_PULSE     = 120;
    localparam H_BACKPORCH      = 64;
    localparam H_WHOLELINE      = 1040;

    localparam V_VISIBLE_AREA   = 600;
    localparam V_FRONTPORCH     = 37;
    localparam V_SYNC_PULSE     = 6;
    localparam V_BACKPORCH      = 23;
    localparam V_WHOLELINE      = 666;

    localparam H_BITS = $clog2(H_WHOLELINE);
    localparam V_BITS = $clog2(V_WHOLELINE);
endpackage

`endif