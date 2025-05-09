`ifndef AXI4_ITF_H
`define AXI4_ITF_H
package axi4_itf;
    localparam AXI_ADDR_BITS = 32;
    localparam AXI_DATA_BITS = 32;
    
    typedef enum logic [1:0] {
        OKAY    = 2'b00,
        EXOKAY  = 2'b01,
        SLVERR  = 2'b10,
        DECERR  = 2'b11
    } BRESP_t;

    typedef struct packed {
        logic [AXI_ADDR_BITS-1:0] awaddr;
        logic [7:0]  awlen;
        logic [2:0]  awsize;
        logic [1:0]  awburst;
        logic        awvalid;

        logic [AXI_DATA_BITS-1:0] wdata;
        logic [AXI_DATA_BITS/8-1:0] wstrb;
        logic        wlast;
        logic        wvalid;
        
        logic        bready;
    } wr_channel_input_t;

    typedef struct packed {
        logic        awready;
        
        logic        wready;

        BRESP_t      bresp;
        logic        bvalid;
    } wr_channel_output_t;

     typedef struct packed {
        logic [AXI_ADDR_BITS-1:0] araddr;
        logic [7:0]               arlen;
        logic [2:0]               arsize;
        logic [1:0]               arburst;
        logic                     arvalid;
        logic                     rready;
    } rd_channel_input_t;

    typedef struct packed {
        logic                     arready;

        logic [AXI_DATA_BITS-1:0] rdata;
        logic [1:0]               rresp;
        logic                     rlast;
        logic                     rvalid;
    } rd_channel_output_t;
endpackage

`endif