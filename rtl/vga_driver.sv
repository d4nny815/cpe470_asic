// * ===========================================================================
// * TOP Module
// * ===========================================================================

`include "axi4_itf.svh"
`include "vga_driver_structs.svh"
`include "vga_timing.sv"
`include "axi_bridge.sv"
`include "control_unit.sv"
`include "pixel_addr_gen.sv"
`include "framebuffer.sv"

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
    output logic                      s_axi_arready,

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
    // * Internal Signals
    // * ======================================================================
    
    // AXI Requests
    logic [PIXEL_ADDR_BITS-1:0] wr_addr, rd_addr;
    logic [DATA_BITS-1:0] wr_data, rd_data;

    // VGA Signals
    logic [VGA_ADDR_BITS-1:0] pixel_addr;
    logic [PIXEL_ADDR_BITS-1:0] fb_pixel_addr;
    logic [V_CNT_BITS-1:0] v_cnt;
    logic [H_CNT_BITS-1:0] h_cnt;
    logic [COLOR_LUT_BITS-1:0] color_ind;

    // Control Signals
    controls_t controls;

    // Status Signals
    logic bridge_init_done;
    statuses_t status;
    
    // * ======================================================================
    // * Control Unit
    // * ======================================================================
    
    assign status.RST_N = 1;
    control_unit control_unit(
        .clk        (vga_clk),
        .statuses   (status),
        .controls   (controls)
    );

    // * ======================================================================
    // * AXI Bridge
    // * ======================================================================
    axi_bridge bridge (
        .wr_re       (controls.wr_re),
        .rd_re       (controls.rd_re),
        .rd_we       (controls.rd_we),
        .wr_addr     (wr_addr),
        .wr_data     (wr_data), 
        .rd_addr     (rd_addr),
        .rd_data     (rd_data),
        .status      (status.axi_comms),
        .init_done   (bridge_init_done),
        .*
    );

    // * ======================================================================
    // * CSR
    // * ======================================================================

    // * ======================================================================
    // * Request Registers
    // * ======================================================================

    // * ======================================================================
    // * VGA Timing
    // * ======================================================================

    vga_timing timing (
    .clk      (vga_clk),
    .reset_n  (vga_reset_n),
    .h_cnt    (h_cnt),
    .h_sync   (vga_hsync),
    .v_cnt    (v_cnt),
    .v_sync   (vga_vsync),
    .in_frame (status.in_frame));

    // * ======================================================================
    // * Pixel Addr Gen
    // * ======================================================================
    
    pixel_addr_gen pixel_addr_gen (
        .clk            (vga_clk),
        .rst_n          (vga_reset_n),
        .h_cnt          (h_cnt),
        .v_cnt          (v_cnt),
        .next           (controls.next), 
        .pixel_addr     (pixel_addr),
        .fb_pixel_addr  (fb_pixel_addr),
        .in_frame       (status.in_frame)
    );

    // * ======================================================================
    // * Framebuffer
    // * ======================================================================

    framebuffer framebuffer(
        .clk                (vga_clk),
        .reset_n            (vga_reset_n),
        .vga_addr           (pixel_addr),
        .fb_vga_addr        (fb_pixel_addr),
        .vga_fetch_next     (controls.next),
        .vga_re             (controls.vga_re),
        .lut_index          (color_ind),
        .pc_sck             (),
        .ps_ce_n            (),
        .ps_din             (),
        .ps_dout            (),
        .ps_douten          (),
        .fb_addr            (),
        .fb_data_i          (),
        .fb_w_r             (),
        .fb_en              (),
        .fb_valid           (),
        .fb_data_o          ()
    );

    // * ======================================================================
    // * Pixel Color LUT
    // * ======================================================================

    // * ======================================================================
    // * DAC
    // * ======================================================================

endmodule