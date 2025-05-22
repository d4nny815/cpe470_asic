// * ===========================================================================
// * TOP Module
// * ===========================================================================

`include "axi4_itf.svh"
`include "vga_timing.sv"

module vga_driver (
    input logic axi_clk,
    input logic axi_reset_n,

    // * AXI-4 SUB : WRITE ADDRESS CHANNEL
    input logic [AXI_ADDR_BITS-1:0]    s_axi_awaddr,
    input logic [7:0]                  s_axi_awlen,
    input logic [2:0]                  s_axi_awsize,
    input logic [1:0]                  s_axi_awburst,
    input logic                        s_axi_awvalid,
    output logic                       s_axi_awready,

    // * AXI-4 SUB : WRITE DATA CHANNEL
    input logic [AXI_DATA_BITS-1:0]    s_axi_wdata,
    input logic [AXI_DATA_BITS/8-1:0]  s_axi_wstrb,
    input logic                        s_axi_wlast,
    input logic                        s_axi_wvalid,
    output logic                       s_axi_wready,

    // * AXI-4 SUB : WRITE RESPONSE CHANNEL
    output logic [1:0]                 s_axi_bresp,
    output logic                       s_axi_bvalid,
    input logic                        s_axi_bready,

    // * AXI-4 SUB : READ ADDRESS CHANNEL
    input logic [AXI_ADDR_BITS-1:0]   s_axi_araddr,
    input logic [7:0]                 s_axi_arlen,
    input logic [2:0]                 s_axi_arsize,
    input logic [1:0]                 s_axi_arburst,
    input logic                       s_axi_arvalid,
    output logic                       s_axi_arready,

    // * AXI-4 SUB : READ DATA CHANNEL
    output logic [AXI_DATA_BITS-1:0]   s_axi_rdata,
    output logic [1:0]                 s_axi_rresp,
    output logic                       s_axi_rlast,
    output logic                       s_axi_rvalid,
    input logic                        s_axi_rready,

    // * VGA OUTPUTS (RGB 8-8-8 + sync)
    input logic         vga_clk,
    input logic         vga_reset_n,
    output logic [7:0]  vga_red,
    output logic [7:0]  vga_green,
    output logic [7:0]  vga_blue,
    output logic        vga_hsync,
    output logic        vga_vsync
    );

    // * ======================================================================
    // * Control Unit
    // * ======================================================================

    // * ======================================================================
    // * AXI Bridge
    // * ======================================================================

    // * ======================================================================
    // * CSR
    // * ======================================================================

    // * ======================================================================
    // * VGA Timing
    // * ======================================================================

    vga_timing timing (
    .clk      (vga_clk),
    .reset_n  (vga_reset_n),
    .h_cnt    (),
    .h_sync   (vga_hsync),
    .v_cnt    (),
    .v_sync   (vga_vsync),
    .in_frame ());

    // * ======================================================================
    // * Pixel Addr Gen
    // * ======================================================================

    // * ======================================================================
    // * Framebuffer
    // * ======================================================================

    // * ======================================================================
    // * Pixel Color LUT
    // * ======================================================================

    // * ======================================================================
    // * DAC
    // * ======================================================================


endmodule