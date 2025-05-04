`include "common/displayConsts.sv"

import displayConsts::*;

module framebuffer (
    input wire [PIXEL_ADDR_BITS - 1 : 0] vgaReadAddr,
    input wire [PIXEL_ADDR_BITS - 1 : 0] pixelWriteAddr,
    input wire [COLOR_BITS - 1 : 0] pixelWriteColor,
    input wire pixel_we,
    output reg [COLOR_CHANNEL_BITS - 1 : 0] vga_red,
    output reg [COLOR_CHANNEL_BITS - 1 : 0] vga_grean,
    output reg [COLOR_CHANNEL_BITS - 1 : 0] vga_blue
    );

    logic [COLOR_BITS - 1 : 0] buffer [0 : FRAME_BUF_SIZE - 1];

endmodule