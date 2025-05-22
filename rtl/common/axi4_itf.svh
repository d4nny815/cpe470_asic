`ifndef AXI4_ITF_H
`define AXI4_ITF_H

localparam AXI_ADDR_BITS = 32;
localparam AXI_DATA_BITS = 32;

typedef enum logic [1:0] {
    OKAY    = 2'b00,
    EXOKAY  = 2'b01,
    SLVERR  = 2'b10,
    DECERR  = 2'b11
} resp_t;

interface axi4_itf;
    

    // ================================================================
    //  WRITE ADDRESS CHANNEL (AW)
    // ================================================================
    logic [AXI_ADDR_BITS-1:0]   awaddr;
    logic [7:0]                 awlen;
    logic [2:0]                 awsize;
    logic [1:0]                 awburst;
    logic                       awvalid;
    logic                       awready;

    // ================================================================
    //  WRITE DATA CHANNEL (W)
    // ================================================================
    logic [AXI_DATA_BITS-1:0]   wdata;
    logic [AXI_DATA_BITS/8-1:0] wstrb;
    logic                       wlast;
    logic                       wvalid;
    logic                       wready;

    // ================================================================
    //  WRITE RESPONSE CHANNEL (B)
    // ================================================================
    resp_t                    bresp;
    logic                     bvalid;
    logic                     bready;

    // ================================================================
    //  READ ADDRESS CHANNEL (AR)
    // ================================================================
    logic [AXI_ADDR_BITS-1:0]   araddr;
    logic [7:0]                 arlen;
    logic [2:0]                 arsize;
    logic [1:0]                 arburst;
    logic                       arvalid;
    logic                       arready;

    // ================================================================
    //  READ DATA CHANNEL (R)
    // ================================================================
    logic [AXI_DATA_BITS-1:0]   rdata;
    resp_t                      rresp;
    logic                       rlast;
    logic                       rvalid;
    logic                       rready;

    modport manager (
        output awaddr, awlen, awsize, awburst, awvalid,
        input  awready,

        output wdata, wstrb, wlast, wvalid,
        input  wready,

        input  bresp, bvalid,
        output bready,

        output araddr, arlen, arsize, arburst, arvalid,
        input  arready,

        input  rdata, rresp, rlast, rvalid,
        output rready
    );

    modport sub (
        input  awaddr, awlen, awsize, awburst, awvalid,
        output awready,

        input  wdata, wstrb, wlast, wvalid,
        output wready,

        output bresp, bvalid,
        input  bready,

        input  araddr, arlen, arsize, arburst, arvalid,
        output arready,

        output rdata, rresp, rlast, rvalid,
        input  rready
    );
endinterface //axi4

`endif