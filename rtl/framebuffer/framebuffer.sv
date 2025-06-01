`ifndef FRAMEBUFFER
`define FRAMEBUFFER

`include "displayConsts.svh"

/**
 * Framebuffer
 *
 * How it works
 * during the blanking period it will fetch next line from the framebuffer to 
 * keep the line cached. A buffer then prefetches 2 (lut indexes) from 
 * the cache and muxes between indexes to give async reads for the color indexes.
 * When there is a write from the fb_channel it is written to main framebuffer 
 * and sets valid onces its done. When there is a read from the fb_channel it 
 * fetches from main framebuffer and sets valid onces its done.
 * 
 * Description
 * -----------
 * This module implements a single-line cached framebuffer for VGA display and
 * AXI-style memory access. It bridges between the VGA logic and a QSPI PSRAM
 * storing the full framebuffer contents.
 * 
 * - During the horizontal blanking interval, `vga_fetch_next` triggers a fetch
 *   of the next scanline (640 bytes) from PSRAM into a local line cache.
 * 
 * - A 2-element prefetch buffer reads ahead from the line cache and muxes LUT
 *   index values to provide single-cycle read access on `vga_re`.
 * 
 * - The external framebuffer access channel (`fb_*`) supports reads and writes
 *   to PSRAM memory. Writes complete with `fb_valid` asserted when done;
 *   reads output the value on `fb_data_o` and assert `fb_valid` once available.

* Ports
 * -----
 * Input:
 *   clk              - VGA/design clock (domain of all logic)
 *   reset_n          - Active-low reset
 * 
 *   VGA pixel fetch interface:
 *   vga_addr         - Pixel address (within scanline) to read from cache
 *   vga_fetch_next   - Signal to trigger loading next scanline from PSRAM
 *   vga_re           - Read enable for current pixel access
 * 
 *   External framebuffer read/write request interface:
 *   fb_addr          - Address for AXI-style access
 *   fb_data_i        - Data to write
 *   fb_w_r           - 1 = write, 0 = read
 *   fb_en            - Enable request
 * 
 * Output:
 *   lut_index        - LUT index at current VGA address (1-byte per pixel)
 *   fb_valid         - Set high when read/write to PSRAM completes
 *   fb_data_o        - Data read from PSRAM (valid when fb_valid is high)
 * 
 *   QSPI PSRAM interface:
 *   pc_sck           - QSPI clock
 *   ps_ce_n          - Active-low chip enable
 *   ps_din           - Input data from PSRAM (DQ[3:0])
 *   ps_dout          - Output data to PSRAM (DQ[3:0])
 *   ps_douten        - Output enable control for QSPI I/Os
 */

module framebuffer (
    input logic clk,
    input logic reset_n,

    // vga signals
    input logic [PIXEL_ADDR_BITS-1:0] vga_addr,
    input logic vga_fetch_next,
    input logic vga_re,
    output logic [COLOR_LUT_BITS-1:0] lut_index,

    // QSPI interface to external PSRAM
    output logic pc_sck,
    output logic ps_ce_n,
    input logic [3:0] ps_din,
    output logic [3:0] ps_dout,
    output logic [3:0] ps_douten,

    // axi request signals
    input logic [PIXEL_ADDR_BITS-1 : 0] fb_addr,
    input logic [COLOR_LUT_BITS-1 : 0] fb_data_i,
    input logic fb_w_r,
    input logic fb_en,
    output logic fb_valid,
    output logic [COLOR_LUT_BITS-1:0] fb_data_o
    );

    // * =======================================================================
    // * Internal signals
    // * =======================================================================


    // * =======================================================================
    // * CONTROL PATH
    // * =======================================================================


    // * =======================================================================
    // * DATA PATH
    // * =======================================================================


endmodule

`endif