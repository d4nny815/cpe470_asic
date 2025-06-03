`timescale 1ns / 1ps
`include "displayConsts.svh"


module pixel_lut_top (
    input logic [COLOR_LUT_BITS-1:0] index,
    input logic mode,
    input logic blackout,
    output logic [COLOR_BITS-1:0] color 
    );

    logic [COLOR_BITS-1:0] color16;
    logic [COLOR_BITS-1:0] color256;
    logic [COLOR_BITS-1:0] selected_color;

    color_lut_16 LUT16(
        .index (index[3:0]),
        .color (color16)
    );

    color_lut_256 LUT256(
        .index (index),
        .color (color256)
    );

    always_comb begin
        // 16 or 256?
        selected_color = (mode == 1'b0) ? color16 : color256;

        // blackout?
        color = (blackout == 1'b1) ? 18'h0000 : selected_color;
    end

endmodule