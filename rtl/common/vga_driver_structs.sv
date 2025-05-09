`ifndef VGA_STRUCTS
`define VGA_STRUCTS

`include "displayConsts.sv"
package vga_driver_structs;
    import displayConsts::*;

    localparam DATA_BITS = COLOR_LUT_BITS;

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
endpackage
`endif 