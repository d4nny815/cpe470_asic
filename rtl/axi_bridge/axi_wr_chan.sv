`ifndef AXI_WR_CHAN
`define AXI_WR_CHAN

`include "axi4_itf.svh"
`include "vga_driver_structs.svh"

/**
 * AXI4 Full Write Channel Slave Interface
 *
 * Implements the slave side of the AXI4 full write channel by coordinating
 * the combined write address (AW) and write data (W) handshake. When
 * `wr_valid` is asserted, the master-side address and data carried on
 * `wr_chan_i` are valid. Once the slave asserts `wr_ready_resp`, the
 * transaction completes and `wr_valid` is deasserted.
 *
 * Ports
 * -----
 * Inputs:
 *   reset_n        : Active-low synchronous reset.
 *   axi_clk        : AXI clock.
 *   wr_chan_i      : Packed write channel input struct, including:
 *   wr_ready_resp  : Slave-side ready response, completing the handshake.
 *
 * Outputs:
 *   wr_chan_o      : Packed write channel output (forwarded or registered).
 *   wr_addr        : Write address [AXI_ADDR_BITS-1:0].
 *   wr_data        : Write data    [AXI_DATA_BITS-1:0].
 *   wr_valid       : Assert when `wr_addr` and `wr_data` are valid.
 */

module axi_wr_chan (
    // * axi 
    input logic reset_n,
    input logic axi_clk,
    // WRITE ADDRESS CHANNEL
    input logic [AXI_ADDR_BITS-1:0]    s_axi_awaddr,
    input logic [7:0]                  s_axi_awlen,
    input logic [2:0]                  s_axi_awsize,
    input logic [1:0]                  s_axi_awburst,
    input logic                        s_axi_awvalid,
    output logic                       s_axi_awready,

    // WRITE DATA CHANNEL
    input logic [AXI_DATA_BITS-1:0]    s_axi_wdata,
    input logic [AXI_DATA_BITS/8-1:0]  s_axi_wstrb,
    input logic                        s_axi_wlast,
    input logic                        s_axi_wvalid,
    output logic                       s_axi_wready,

    // WRITE RESPONSE CHANNEL
    output logic [1:0]                 s_axi_bresp,
    output logic                       s_axi_bvalid,
    input logic                        s_axi_bready,
    
    // * design
    input logic wr_ready_resp,
    output logic [AXI_ADDR_BITS-1:0] wr_addr,
    output logic [AXI_DATA_BITS-1:0] wr_data,
    output logic wr_valid
    );

    // * =======================================================================
    // * Internal Signals
    // * =======================================================================
    typedef enum logic [1:0] {
        READY       = 2'b00,
        VALID       = 2'b01,
        WAIT_RESP   = 2'b10
    } state_t;
    state_t PS, NS;

    always_ff @(posedge axi_clk or negedge reset_n) begin
        if (!reset_n) PS <= READY;
        else          PS <= NS;
    end

    // * =======================================================================
    // * CONTROL PATH
    // * =======================================================================

    logic awready_r, wready_r, bvalid_r;
    resp_t bresp_r;
    logic wr_addr_we, wr_data_we;

    assign s_axi_awready = awready_r;
    assign s_axi_wready  = wready_r;
    assign s_axi_bvalid  = bvalid_r;
    assign s_axi_bresp   = bresp_r;

    always_comb begin
        awready_r = 0;
        wready_r  = 0;
        bvalid_r  = 0;
        bresp_r   = OKAY;
        wr_valid = 1'b0;
        wr_addr_we = 1'b0;
        wr_data_we = 1'b0;

        case (PS)
            READY: begin
                awready_r = 1;
                wready_r = 1;
                if (s_axi_awvalid && s_axi_wvalid) begin 
                    wr_addr_we = 1'b1;
                    wr_data_we = 1'b1;
                    NS = VALID;
                end
                else
                    NS = READY;
            end
            
            VALID: begin
                wr_valid = 1;
                if (wr_ready_resp) begin
                    NS = WAIT_RESP;
                end
                else begin
                    NS = VALID;
                end
            end

            WAIT_RESP: begin
                bvalid_r = 1'b1;
                bresp_r  = OKAY;

                if (s_axi_bready) NS = READY;
                else NS = WAIT_RESP;
            end

            default: NS = READY;
        endcase
    end

    // * ==========================================================================
    // * DATA PATH
    // * ==========================================================================
    logic [AXI_ADDR_BITS-1:0] awaddr_r;
    logic [AXI_DATA_BITS-1:0] wdata_r;
    always_ff @(posedge axi_clk or negedge reset_n) begin
        if (!reset_n) begin
            awaddr_r <= 'hdeadbeef;
            wdata_r  <= 'hdeadbeef;
        end else begin
                if (wr_addr_we)
                    awaddr_r <= s_axi_awaddr;

                if (wr_data_we)
                    wdata_r <= s_axi_wdata;
        end
    end

    always_comb begin
        wr_addr = wr_valid ? awaddr_r : 32'hdeadbeef;
        wr_data = wr_valid ? wdata_r : 32'hdeadbeef;
    end


endmodule

`endif