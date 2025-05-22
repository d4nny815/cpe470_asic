// TODO: danny
`include "displayConsts.svh"

module framebuffer (
    input logic [PIXEL_ADDR_BITS-1 : 0] vga_addr,
    input logic vga_fetch_next,
    input logic vga_re,
    input logic [PIXEL_ADDR_BITS-1 : 0] fb_addr,
    input logic [COLOR_LUT_BITS-1 : 0]     fb_data_i,
    input logic fb_w_r,
    input logic fb_en,
    output logic [COLOR_LUT_BITS-1 : 0] lut_index,
    output logic fb_valid,
    output logic [COLOR_LUT_BITS-1:0] fb_data_o
    );

    logic [COLOR_BITS-1 : 0] buffer [0 : FRAME_SIZE-1];

endmodule