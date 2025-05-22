// * ===========================================================================
// * TOP Module
// * ===========================================================================

`include "axi4_itf.svh"

module vga_driver (
    input logic axi_clk,
    input logic axi_reset_n,

    // ========================================================
    //  AXI-4 SLAVE : WRITE ADDRESS CHANNEL
    // ========================================================
    input logic [AXI_ADDR_BITS-1:0]    s_axi_awaddr,
    input logic [7:0]                  s_axi_awlen,
    input logic [2:0]                  s_axi_awsize,
    input logic [1:0]                  s_axi_awburst,
    input logic                        s_axi_awvalid,
    output logic                       s_axi_awready,

    // ========================================================
    //  AXI-4 SLAVE : WRITE DATA CHANNEL
    // ========================================================
    input logic [AXI_DATA_BITS-1:0]    s_axi_wdata,
    input logic [AXI_DATA_BITS/8-1:0]  s_axi_wstrb,
    input logic                        s_axi_wlast,
    input logic                        s_axi_wvalid,
    output logic                       s_axi_wready,

    // ========================================================
    //  AXI-4 SLAVE : WRITE RESPONSE CHANNEL
    // ========================================================
    output logic [1:0]                 s_axi_bresp,
    output logic                       s_axi_bvalid,
    input logic                        s_axi_bready,

    // ========================================================
    //  AXI-4 SLAVE : READ ADDRESS CHANNEL
    // ========================================================
    input logic [AXI_ADDR_BITS-1:0]   s_axi_araddr,
    input logic [7:0]                 s_axi_arlen,
    input logic [2:0]                 s_axi_arsize,
    input logic [1:0]                 s_axi_arburst,
    input logic                       s_axi_arvalid,
    output logic                       s_axi_arready,

    // ========================================================
    //  AXI-4 SLAVE : READ DATA CHANNEL
    // ========================================================
    output logic [AXI_DATA_BITS-1:0]   s_axi_rdata,
    output logic [1:0]                 s_axi_rresp,
    output logic                       s_axi_rlast,
    output logic                       s_axi_rvalid,
    input logic                        s_axi_rready,

    // ========================================================
    //  VGA OUTPUTS (RGB 8-8-8 + sync)
    // ========================================================
    input logic         vga_clk,
    input logic         vga_reset_n,
    output logic [7:0]  vga_red,
    output logic [7:0]  vga_green,
    output logic [7:0]  vga_blue,
    output logic        vga_hsync,
    output logic        vga_vsync
    );

    // * ======================================================================
    // *  AXI Interface
    // * ======================================================================

    axi4_itf s_axi_if();
    // Address write (AW)
    assign s_axi_if.awaddr  = s_axi_awaddr;
    assign s_axi_if.awlen   = s_axi_awlen;
    assign s_axi_if.awsize  = s_axi_awsize;
    assign s_axi_if.awburst = s_axi_awburst;
    assign s_axi_if.awvalid = s_axi_awvalid;
    assign s_axi_awready    = s_axi_if.awready;

    // Write data (W)
    assign s_axi_if.wdata   = s_axi_wdata;
    assign s_axi_if.wstrb   = s_axi_wstrb;
    assign s_axi_if.wlast   = s_axi_wlast;
    assign s_axi_if.wvalid  = s_axi_wvalid;
    assign s_axi_wready     = s_axi_if.wready;

    // Write response (B)
    assign s_axi_bresp      = s_axi_if.bresp;
    assign s_axi_bvalid     = s_axi_if.bvalid;
    assign s_axi_if.bready  = s_axi_bready;

    // Read address (AR)
    assign s_axi_if.araddr  = s_axi_araddr;
    assign s_axi_if.arlen   = s_axi_arlen;
    assign s_axi_if.arsize  = s_axi_arsize;
    assign s_axi_if.arburst = s_axi_arburst;
    assign s_axi_if.arvalid = s_axi_arvalid;
    assign s_axi_arready    = s_axi_if.arready;

    // Read data (R)
    assign s_axi_rdata      = s_axi_if.rdata;
    assign s_axi_rresp      = s_axi_if.rresp;
    assign s_axi_rlast      = s_axi_if.rlast;
    assign s_axi_rvalid     = s_axi_if.rvalid;
    assign s_axi_if.rready  = s_axi_rready;

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