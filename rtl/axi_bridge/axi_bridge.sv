`ifndef AXI_BRIDGE
`define AXI_BRIDGE

`include "axi4_itf.svh"
`include "vga_driver_structs.svh"
`include "displayConsts.svh"
`include "axi_wr_chan.sv"
// `include "axi_rd_chan.sv"
`include "ASYNC_FIFO.sv"


/**
 * AXI–VGA Subsystem Bridge
 *
 * Bridges AXI4 write and read channels in the AXI clock domain into
 * simple request/response signals in the VGA (design) clock domain.
 * Handles reset synchronization, clock-domain crossing, and an
 * initialization handshake before normal operation.
 *
 * Operation:
 *  - In the VGA domain, assert `wr_re` or `rd_re` to issue a write or read
 *    request. On that same cycle, the corresponding `wr_addr`, `wr_data`,
 *    or `rd_addr` outputs appear (asynchronous reads). 
 *  - When read data is ready, assert `rd_we` and present it on `rd_data` for
 *    the AXI master.
 *  - In the AXI domain, `wr_chan_i`/`rd_chan_i` carry AW+W or AR channel
 *    inputs; `wr_chan_o`/`rd_chan_o` report AWREADY+WREADY or RVALID+RDATA.
 *  - `status` reflects VGA transaction flags for VGA controller; `init_done` indicates
 *    completion of reset release and synchronization.
 *
 * Ports
 * -----
 * * AXI interface
 * * Input
 * axi_clk,      // AXI clock
 * axi_reset_n,  // Active‐low reset (AXI domain)
 * wr_chan_i,    // AXI write channel input (AW+W bundled)
 * rd_chan_i,    // AXI read channel input (AR)
 * * Output
 * wr_chan_o,    // AXI write channel output (AWREADY+WREADY)
 * rd_chan_o,    // AXI read channel output (RVALID+RDATA+RRESP)
 *
 * * Design/VGA interface
 * * Input
 * vga_reset_n,  // Active‐low reset (VGA domain)
 * vga_clk,      // VGA/design clock
 * wr_re,        // Write request enable (design → bridge)
 * wr_addr,     // Write address to design
 * wr_data,      // Write data    to design
 * rd_re,        // Read  request enable (design → bridge)
 * rd_addr,     // Read  address to design
 * * Output
 * rd_we,        // Read-data valid from design
 * rd_data,      // Read-data from design
 * status,       // Read/Write transaction flags
 * init_done     // Asserted when initialization is complete
 */

module axi_bridge (
    // axi channels
    input logic axi_reset_n,
    input logic axi_clk,
    axi4_itf.sub s_if,
    
    // design channels
    input logic         vga_reset_n,
    input logic         vga_clk,
    input logic         wr_re,
    input logic         rd_re,
    input logic         rd_we,
    input logic [DATA_BITS-1:0]         rd_data,
    output logic [PIXEL_ADDR_BITS-1:0]  wr_addr,
    output logic [DATA_BITS-1:0]        wr_data, 
    output logic [PIXEL_ADDR_BITS-1:0]  rd_addr,
    output axi_comms_status_t           status,
    output logic                        init_done
    );

    // * =======================================================================
    // * Internal Signals
    // * =======================================================================

    typedef enum logic { 
        INIT,
        RUNNING
    } state_t;
    state_t PS, NS;

    always_ff @(posedge vga_clk or negedge axi_reset_n or negedge vga_reset_n) begin
        if (!vga_reset_n || !axi_reset_n) 
            PS <= INIT;
        else
            PS <= NS;
    end

    // * =======================================================================
    // * CONTROL PATH
    // * =======================================================================

    logic int_reset_n;

    // status signals
    logic axi_wr_recieved, wr_fifo_empty, wr_fifo_full, wr_fifo_valid_packet;
    logic axi_rd_recieved, rda_fifo_empty, rda_fifo_full, rd_fifo_valid_packet;
    logic rdd_fifo_empty, rdd_fifo_full, axi_rd_waiting;
    
    // control signals
    logic wr_req, wr_full;
    logic wr_ready_resp, wr_fifo_we, wr_fifo_re;
    logic rd_ready_read;
    
    logic rd_req, rd_full;
    logic rda_ready_read, rda_fifo_we, rda_fifo_re;

    logic rdd_fifo_we, rdd_fifo_re;
    logic axi_rd_we;

    always_comb begin
        NS = PS;
        init_done = 0;
        wr_ready_resp = 0;
        wr_fifo_we = 0;
        wr_fifo_re = 0;

        rda_ready_read = 0;
        rda_fifo_we = 0;
        rda_fifo_re = 0;

        rdd_fifo_we = 0;
        rdd_fifo_re = 0;
        axi_rd_we = 0;
        
        case(PS)
            INIT: begin
                int_reset_n = axi_reset_n & vga_reset_n;
                if (int_reset_n)
                    NS = RUNNING;                
            end

            RUNNING: begin
                init_done = 1;

                // wr requests
                wr_ready_resp   = !wr_fifo_full;
                wr_fifo_we      = axi_wr_recieved && wr_fifo_valid_packet && !wr_fifo_full;
                wr_fifo_re      = wr_re && !wr_fifo_empty;
                wr_full         = wr_fifo_full;
                wr_req          = !wr_fifo_empty;

                // rd requests
                // rd addr
                rda_ready_read  = !rda_fifo_full;
                rda_fifo_we     = axi_rd_recieved && rd_fifo_valid_packet && !rda_fifo_full;
                rda_fifo_re     = rd_re && !rda_fifo_empty;
                rd_full         = rda_fifo_full;
                rd_req          = !rda_fifo_empty;

                // rd data
                axi_rd_we       = axi_rd_waiting && !rdd_fifo_empty;
                rdd_fifo_we     = rd_we && !rdd_fifo_full;
                rdd_fifo_re     = rd_re && !rdd_fifo_empty; // ? whats this cond
            end
            default : NS = INIT;
        endcase
    end

    // * =======================================================================
    // * DATA PATH
    // * =======================================================================
    logic [AXI_ADDR_BITS-1:0] wr_addr_axi;
    logic [AXI_DATA_BITS-1:0] wr_data_axi;

    logic [AXI_ADDR_BITS-1:0] rd_addr_axi;
    logic [DATA_BITS-1:0] rd_data_small;

    // * WRITE REQUESTS 
    // TODO: fix, hangs for sim time
    axi_wr_chan wr_chan (
        .reset_n            (axi_reset_n),
        .axi_clk            (axi_clk),
        .s_if               (s_if),
        .wr_ready_resp      (wr_ready_resp),
        .wr_addr            (wr_addr_axi),
        .wr_data            (wr_data_axi),
        .wr_valid           (axi_wr_recieved)
    );

    // write packet encoder
    typedef struct packed {
        fb_csr_t fb_csr;
        logic [PIXEL_ADDR_BITS-1:0] addr;
        logic [COLOR_LUT_BITS-1:0] data;
    } wr_fifo_packet_t;

    wr_fifo_packet_t wr_fifo_data_i, wr_fifo_data_o;
    logic [PIXEL_ADDR_BITS-1:0] wr_addr_sliced;
    logic [COLOR_LUT_BITS-1:0] wr_data_sliced;

    assign wr_addr_sliced = wr_addr_axi[PIXEL_ADDR_BITS-1:0];
    assign wr_data_sliced = wr_data_axi[COLOR_LUT_BITS-1:0];

    always_comb begin
        wr_fifo_data_i.addr = wr_addr_sliced;
        wr_fifo_data_i.data = wr_data_sliced;
        if (wr_addr_sliced < CSR_ADDR_OFFSET)
            wr_fifo_data_i.fb_csr = FB;
        else
            wr_fifo_data_i.fb_csr = CSR;
        
        wr_fifo_valid_packet = ((wr_addr_axi >= AXI_FB_ADDR && wr_addr_axi < AXI_CSR_ADDR) || 
                            (wr_addr_axi >= AXI_CSR_ADDR && wr_addr_axi < AXI_CSR_ADDR + 1));
    end

    ASYNC_FIFO #( 
        .DSIZE($bits(wr_fifo_packet_t)),
        .ASIZE(WRITE_REQ_FIFO_BITS)
        ) wr_fifo (
        .rrst_n     (vga_reset_n),         // Read increment, read clock, read reset
        .rclk       (vga_clk), 
        .rinc       (wr_fifo_re), 
        .wdata      (wr_fifo_data_i),      // Input data - data to be written
        .wrst_n     (axi_reset_n),         // Write increment, write clock, write reset
        .wclk       (axi_clk), 
        .winc       (wr_fifo_we), 
        .rdata      (wr_fifo_data_o),      // Output data - data to be read
        .rempty     (wr_fifo_empty),       // Read empty signal
        .wfull      (wr_fifo_full)       // Write full signal
    );

    assign status.wr_req     = wr_req;
    assign status.wr_full    = wr_full;
    assign status.wr_fb_csr  = wr_fifo_data_o.fb_csr;
    assign wr_addr           = wr_fifo_data_o.addr;
    assign wr_data           = wr_fifo_data_o.data;

    // * READ REQUESTS 

    // read addr
    // TODO: add axi rd channel module
    axi_rd_chan rd_chan (
        .reset_n        (axi_reset_n),
        .axi_clk        (axi_clk),
        .s_if           (s_if),
        .rd_we          (axi_rd_we), 
        .rd_data        (),
        .rd_ready_read  (rd_ready_read),
        .rd_addr        (rd_addr_axi),
        .rd_valid       (axi_rd_recieved),
        .waiting        (axi_rd_waiting)
    );

    // read packet encoder
    typedef struct packed {
        fb_csr_t fb_csr;
        logic [PIXEL_ADDR_BITS-1:0] addr;
    } rd_fifo_packet_t;

    rd_fifo_packet_t rda_fifo_data_i, rda_fifo_data_o;
    logic [PIXEL_ADDR_BITS-1:0] rd_addr_sliced;

    assign rd_addr_sliced = rd_addr_axi[PIXEL_ADDR_BITS-1:0];

    always_comb begin
        rda_fifo_data_i.addr = rd_addr_sliced;
        if (rd_addr_sliced < CSR_ADDR_OFFSET)
            rda_fifo_data_i.fb_csr = FB;
        else
            rda_fifo_data_i.fb_csr = CSR;
        
        rd_fifo_valid_packet = ((rd_addr_axi >= AXI_FB_ADDR && rd_addr_axi < AXI_CSR_ADDR) || 
                            (rd_addr_axi >= AXI_CSR_ADDR && rd_addr_axi <= AXI_CSR_ADDR + 1));
    end

    ASYNC_FIFO #( 
        .DSIZE($bits(rd_fifo_packet_t)),
        .ASIZE(READ_REQ_FIFO_BITS)
    ) rd_addr_fifo (
        .rrst_n     (vga_reset_n),         // Read increment, read clock, read reset
        .rclk       (vga_clk), 
        .rinc       (rda_fifo_re), 
        .rdata      (rda_fifo_data_o),      // Output data - data to be read
        .wrst_n     (axi_reset_n),         // Write increment, write clock, write reset
        .wclk       (axi_clk), 
        .winc       (rda_fifo_we), 
        .wdata      (rda_fifo_data_i),      // Input data - data to be written
        .rempty     (rda_fifo_empty),       // Read empty signal
        .wfull      (rda_fifo_full)       // Write full signal
    );

    // read data
    ASYNC_FIFO #( 
        .DSIZE(DATA_BITS),
        .ASIZE(READ_REQ_FIFO_BITS)
    ) rd_data_fifo (
        .rrst_n     (axi_reset_n),         // Read increment, read clock, read reset
        .rclk       (axi_clk), 
        .rinc       (rdd_fifo_re), 
        .rdata      (rd_data_small),        // Output data - data to be read
        .wrst_n     (vga_reset_n),         // Write increment, write clock, write reset
        .wclk       (vga_clk), 
        .winc       (rdd_fifo_we), 
        .wdata      (rd_data),              // Input data - data to be written
        .rempty     (rdd_fifo_empty),       // Read empty signal
        .wfull      (rdd_fifo_full)         // Write full signal
    );

    assign status.rd_req    = rd_req;
    assign status.rd_full   = rda_fifo_full;
    assign status.rd_fb_csr = rda_fifo_data_o.fb_csr;
    assign rd_addr          = rda_fifo_data_o.addr;

endmodule
`endif