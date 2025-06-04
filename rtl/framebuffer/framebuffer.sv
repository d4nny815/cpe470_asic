`ifndef FRAMEBUFFER
`define FRAMEBUFFER

`include "displayConsts.svh"
`include "line_cache.sv"
`include "EF_PSRAM_CTRL.sv"

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
    input logic CLK_200MHz,
    input logic reset_n,

    // vga signals
    input logic [VGA_ADDR_BITS-1:0] vga_addr,
    input logic [PIXEL_ADDR_BITS-1:0] fb_vga_addr,
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

    localparam WORDS_PER_LINE = H_VISIBLE_AREA/4-1;

    // * =======================================================================
    // * Internal signals
    // * =======================================================================

    logic [H_CNT_BITS-1:0] prefetch_addr;
    logic [H_CNT_BITS-1:0] lc_waddr;
    logic [(4*COLOR_LUT_BITS)-1:0] lc_wdata;

    logic [23:0] ps_addr;
    logic [31:0] ps_wdata, ps_rdata;
    logic [2:0] ps_size;

    logic [$clog2(WORDS_PER_LINE)-1:0]  word_cnt;
    logic [23:0] cur_addr;

    // * =======================================================================
    // * CONTROL PATH
    // * =======================================================================

    logic lc_we;
    logic ps_start, ps_done, ps_wr, ps_dma_addr_we, ps_host_addr_we;
    logic dma_issue;

    typedef enum logic [2:0] {
        IDLE, 
        DMA_ISSUE, 
        DMA_WAIT, 
        DMA_STORE,
        HOST_ISSUE, 
        HOST_WAIT,
        HOST_DONE
    } state_t;
    state_t  PS, NS;
    
    

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            PS <= IDLE;
        end else begin
            PS <= NS;
        end
    end

    always_comb begin
        NS = PS;
        ps_start  = 1'b0;
        ps_size   = 3'd4;
        ps_wr     = 1'b0;
        ps_dma_addr_we = 0;
        ps_host_addr_we = 0;
        dma_issue = 0;

        lc_we = 1'b0;

        fb_valid = 0;

        case (PS)
            IDLE: begin
                if (fb_en) begin
                    ps_host_addr_we = 1;
                    NS = HOST_ISSUE;
                end
                else if (vga_fetch_next) begin
                    ps_dma_addr_we = 1;
                    NS = DMA_ISSUE;
                end
            end

            DMA_ISSUE: begin
                dma_issue = 1;
                ps_start = 1;
                NS = DMA_WAIT;
            end

            DMA_WAIT: begin
                if (ps_done) NS = DMA_STORE;
            end

            DMA_STORE: begin
                lc_we = 1;
                if (word_cnt == WORDS_PER_LINE[6:0]) begin
                    ps_dma_addr_we = 1;
                    NS = IDLE;
                end
                else
                    NS = DMA_ISSUE;
            end

            HOST_ISSUE: begin
                ps_wr = fb_w_r;
                ps_size = 3'd1;
                ps_start = 1;
                NS = HOST_WAIT;
            end

            HOST_WAIT: begin
                if (ps_done) 
                    NS = HOST_DONE;
            end

            HOST_DONE: begin
                fb_valid = 1;
                NS = IDLE;
            end

            default NS = IDLE;
        endcase
    end

    // * =======================================================================
    // * DATA PATH
    // * =======================================================================
    
    // cache line adapter
    always_ff @(posedge clk) begin
        if (ps_dma_addr_we) begin
            word_cnt <= '0;
            ps_addr <= {7'b0, fb_vga_addr};
        end
        else if (ps_host_addr_we) begin
            ps_addr <= {7'b0, fb_addr};
        end

        else if (dma_issue) begin
            ps_addr <= ps_addr + 4;
        end

        if (lc_we) begin
            word_cnt <= word_cnt + 1;
        end
    end

    always_comb begin
        lc_waddr = {word_cnt, 2'b00};
        ps_wdata = {24'b0, fb_data_i};
    end

    // address decoder
    always_comb begin
        prefetch_addr = !vga_re ? 'd0 : vga_addr[H_CNT_BITS-1:0] + 'd1;
    end

    line_cache line (
        .clk_write  (CLK_200MHz),
        .we         (lc_we),
        .wr_addr    (lc_waddr),
        .wr_data    (ps_rdata),
        .clk_read   (clk),
        .rd_addr    (prefetch_addr),
        .rd_data    (lut_index)
    );


    EF_PSRAM_CTRL psram_i (
        /* control handshake */
        .rst_n      (reset_n),
        .clk        (CLK_200MHz),
        .addr       (ps_addr),
        .data_i     (ps_wdata),
        .data_o     (ps_rdata),
        .size       (ps_size),
        .start      (ps_start),
        .done       (ps_done),

        .wait_states(4'd6),
        .cmd        (ps_wr ? 8'h38 : 8'hEB), // 0xEB = Fast-Quad-Read
        .rd_wr      (ps_wr),
        .qspi       (1'b1),
        .qpi        (1'b0),
        .short_cmd  (1'b0),

        .sck        (pc_sck),
        .ce_n       (ps_ce_n),
        .din        (ps_din),
        .dout       (ps_dout), 
        .douten     (ps_douten)
    );

    assign fb_data_o = fb_valid ? ps_rdata[7:0] : 8'hff;

endmodule

`endif