`ifndef AXI4_ITF_H
`define AXI4_ITF_H
package axi4_itf;
    typedef struct packed {
        logic [31:0] awaddr;
        logic [7:0]  awlen;
        logic [2:0]  awsize;
        logic [1:0]  awburst;
        logic        awvalid;
        logic        awready;
    } axi4_aw_t;

    typedef struct packed {
        logic [31:0] wdata;
        logic [3:0]  wstrb;
        logic        wlast;
        logic        wvalid;
        logic        wready;
    } axi4_w_t;

    typedef struct packed {
        logic [1:0]  bresp;
        logic        bvalid;
        logic        bready;
    } axi4_b_t;

    typedef struct packed {
        logic [31:0] araddr;
        logic [7:0]  arlen;
        logic [2:0]  arsize;
        logic [1:0]  arburst;
        logic        arvalid;
        logic        arready;
    } axi4_ar_t;

    typedef struct packed {
        logic [31:0] rdata;
        logic [1:0]  rresp;
        logic        rlast;
        logic        rvalid;
        logic        rready;
    } axi4_r_t;
endpackage

`endif