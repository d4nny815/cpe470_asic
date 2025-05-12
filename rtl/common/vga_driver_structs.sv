`ifndef VGA_STRUCTS
`define VGA_STRUCTS

`include "displayConsts.sv"
package vga_driver_structs;
    import displayConsts::*;

    localparam DATA_BITS = COLOR_LUT_BITS;

    localparam AXI_BASE_ADDR = 32'h11000000;
    localparam FB_ADDR_OFFSET = 0;
    localparam CSR_ADDR_OFFSET = FRAME_SIZE;
    localparam AXI_FB_ADDR = AXI_BASE_ADDR + FB_ADDR_OFFSET;
    localparam AXI_CSR_ADDR = AXI_BASE_ADDR + CSR_ADDR_OFFSET;
    localparam FB_ADDR = FB_ADDR_OFFSET;
    localparam CR_ADDR = CSR_ADDR_OFFSET;
    localparam SR_ADDR = CR_ADDR + 1;

    localparam WRITE_REQ_FIFO_BITS = 4;
    localparam WRITE_REQ_FIFO_SIZE = 1 << WRITE_REQ_FIFO_BITS;

    typedef enum logic { 
        FB = 1'b0,
        CSR = 1'b1
    } fb_csr_t;

    typedef struct packed {
        logic wr_full;
        logic wr_req;
        fb_csr_t wr_fb_csr;
        logic [PIXEL_ADDR_BITS-1:0] wr_addr;
        logic [DATA_BITS-1:0] wr_data;
        logic rd_full;
        logic rd_req;
        fb_csr_t rd_fb_csr;
        logic [PIXEL_ADDR_BITS-1:0] rd_addr;
    } axi_comms_status_t;

    typedef struct packed {
        logic RST_N;
        
        // vga timing
        logic in_frame;

        // w/r reqs
        axi_comms_status_t axi_comms;
    } statuses_t;

    typedef struct packed {
        logic reset_n;
        
        // timing 
        logic next;
        logic vga_fetch;

        // w/r reqs
        logic wr_ld; 
        logic rd_ld;
        logic cr_ld;
        logic fb_w_r;
        logic fb_en;
        logic wr_re;
        logic rd_re;
        logic rd_we;
        logic [1:0] rd_data_sel;
    } controls_t;
endpackage
`endif 