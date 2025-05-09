`ifndef DISPLAY_CONSTS_H
`define DISPLAY_CONSTS_H

`include "vgaTimes.sv"

package displayConsts;
    import vgaTimes::*;

    localparam COLOR_LUT_BITS       = 8;
    localparam COLOR_BITS           = 18;
    localparam COLOR_CHANNEL_BITS   = COLOR_BITS / 3;

    localparam H_CNT_BITS = $clog2(H_VISIBLE_AREA); 
    localparam V_CNT_BITS = $clog2(V_VISIBLE_AREA);

    localparam FRAME_SIZE = H_VISIBLE_AREA * V_VISIBLE_AREA; 
    localparam PIXEL_ADDR_BITS = $clog2(FRAME_SIZE);
endpackage

`endif