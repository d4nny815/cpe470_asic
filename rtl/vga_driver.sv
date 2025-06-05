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
`include "pixel_lut_top.sv"
`include "avsddac.sv"

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

    // * QSPI interface to external PSRAM
    output logic pc_sck,
    output logic ps_ce_n,
    input logic [3:0] ps_din,
    output logic [3:0] ps_dout,
    output logic [3:0] ps_douten,

    // * VGA OUTPUTS (RGB 8-8-8 + sync)
    input logic         CLK_200MHz,
    input logic         vga_clk,
    input logic         vga_reset_n,
    output logic [15:0] vga_red,
    output logic [15:0] vga_green,
    output logic [15:0] vga_blue,
    output logic        vga_hsync,
    output logic        vga_vsync
    );

    // Pixel LUT Signals
    logic [COLOR_BITS - 1 : 0] color;

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

    // FrameBuffer Signals
    logic [COLOR_LUT_BITS-1:0] fb_pixel_o;

    // CSR
    logic [7:0] reg_cr, reg_sr;
    logic [PIXEL_ADDR_BITS-1:0] reg_wr_addr, reg_rd_addr;
    logic [DATA_BITS-1:0] reg_wr_data, reg_rd_data;

    // Control Signals
    controls_t controls;

    // Status Signals
    logic bridge_init_done;
    statuses_t status;

    // * ======================================================================
    // * Control Unit
    // * ======================================================================
    
    assign status.RST_N = vga_reset_n && axi_reset_n;
    control_unit control_unit(
        .clk        (vga_clk),
        .statuses   (status),
        .controls   (controls)
    );

    // * ======================================================================
    // * AXI Bridge
    // * ======================================================================
    
    // rd data mux
    always_comb begin
        case (controls.rd_data_sel)
            0: rd_data = fb_pixel_o;
            1: rd_data = reg_cr;
        default: rd_data = 8'b1000_0001; 
        endcase
    end
    
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
        .axi_reset_n (controls.reset_n),
        .vga_reset_n (controls.reset_n),
        .* // axi signals
    );

    // * ======================================================================
    // * CSR
    // * ======================================================================

    always_comb begin
        reg_sr = 8'b0;
    end

    always_ff @(posedge vga_clk) begin
        if (!controls.reset_n) begin
            reg_cr <= 'd0;
        end
        else if (controls.cr_ld) begin
            reg_cr <= wr_data[7:0];
        end 
    end


    // * ======================================================================
    // * Request Registers
    // * ======================================================================

    always_ff @(posedge vga_clk) begin
        if (controls.wr_ld) begin
           reg_wr_addr <= wr_addr;
           reg_wr_data <= wr_data;  
        end

        if (controls.rd_ld) begin
            reg_rd_addr <= rd_addr;
        end
    end

    // * ======================================================================
    // * VGA Timing
    // * ======================================================================

    vga_timing timing (
        .clk      (vga_clk),
        .reset_n  (controls.reset_n),
        .h_cnt    (h_cnt),
        .h_sync   (vga_hsync),
        .v_cnt    (v_cnt),
        .v_sync   (vga_vsync),
        .in_frame (status.in_frame)
    );

    // * ======================================================================
    // * Pixel Addr Gen
    // * ======================================================================
    
    pixel_addr_gen pixel_addr_gen (
        .clk            (vga_clk),
        .rst_n          (controls.reset_n),
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
        .CLK_200MHz         (CLK_200MHz),
        .reset_n            (controls.reset_n),
        .vga_addr           (pixel_addr),
        .fb_vga_addr        (fb_pixel_addr),
        .vga_fetch_next     (controls.next),
        .vga_re             (controls.vga_re),
        .lut_index          (color_ind),
        .fb_addr            (controls.addr_sel ? reg_rd_addr : reg_wr_addr),
        .fb_data_i          (reg_wr_data),
        .fb_w_r             (controls.fb_w_r),
        .fb_en              (controls.fb_en),
        .fb_valid           (status.fb_valid),
        .fb_data_o          (fb_pixel_o),
        .* // qspi signals
    );

    // * ======================================================================
    // * Pixel Color LUT
    // * ======================================================================
    pixel_lut_top pixel_lut(
        .index      (color_ind),
        .mode       (reg_cr[VGA_MODE_BIT]),
        .blackout   (reg_cr[BLK_OUT_BIT]),
        .color      (color) 
    );
    
    // * ======================================================================
    // * DAC
    // * ======================================================================
    avsddac red_dac(
        .VREFH  (VREFH),
        .VREFL  (VREFL),
        .D      (color[17:12]), // top 6 bits
        .EN     (1'b1),
        .OUT    (vga_red)
    );

    avsddac green_dac(
        .VREFH  (VREFH),
        .VREFL  (VREFL),
        .D      (color[11:6]), // middle 6 bits
        .EN     (1'b1),
        .OUT    (vga_green)
    );

    avsddac blue_dac(
        .VREFH  (VREFH),
        .VREFL  (VREFL),
        .D      (color[5:0]), // bottom 6 bits
        .EN     (1'b1),
        .OUT    (vga_blue)
    );  

endmodule