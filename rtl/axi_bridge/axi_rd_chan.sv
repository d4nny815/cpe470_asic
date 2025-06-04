`ifndef AXI_RD_CHAN
`define AXI_RD_CHAN

`include "axi4_itf.svh"
`include "vga_driver_structs.svh"

/**
 * AXI4 Full Read Channel Slave Interface
 *
 * Coordinates the AXI4 full read channel by handling both the read address (AR)
 * and read data (R) handshakes. When `rd_valid` is asserted, the address on
 * `s_if` is valid. The slave asserts `rd_ready_read` (ARREADY) to accept
 * that address. Once data is available, the slave drives `rd_data` and asserts
 * `rd_we` (RVALID). The `waiting` flag remains high while a read request is
 * pending data.
 *
 * Ports
 * -----
 * Inputs:
 *   reset_n         : Active-low synchronous reset.
 *   axi_clk         : AXI clock.
 *   s_if       : Packed read channel input struct
 *   rd_we           : Read-data valid from slave
 *   rd_data         : Read data from slave
 *   rd_ready_read   : Slave ready to accept read addr
 *
 * Outputs:
 *   s_if       : Packed read channel output (forwarded or registered).
 *   rd_addr         : Read address
 *   rd_valid        : Assert when `rd_addr` is valid
 *   waiting         : High while awaiting read-data from slave.
 */

module axi_rd_chan (
    // * axi
    input logic reset_n,
    input logic axi_clk,

    //  READ ADDRESS CHANNEL
    input logic [AXI_ADDR_BITS-1:0]   s_axi_araddr,
    input logic [7:0]                 s_axi_arlen,
    input logic [2:0]                 s_axi_arsize,
    input logic [1:0]                 s_axi_arburst,
    input logic                       s_axi_arvalid,
    output logic                      s_axi_arready,

    //  READ DATA CHANNEL
    output logic [AXI_DATA_BITS-1:0]   s_axi_rdata,
    output logic [1:0]                 s_axi_rresp,
    output logic                       s_axi_rlast,
    output logic                       s_axi_rvalid,
    input logic                        s_axi_rready,

    // * design
    input logic rd_we, 
    input logic [AXI_DATA_BITS-1:0] rd_data,
    input logic rd_ready_read,
    output logic [AXI_ADDR_BITS-1:0] rd_addr,
    output logic rd_valid,
    output logic waiting
    );

    // ==========================================================================
    // Internal signals
    // ==========================================================================
    logic [AXI_ADDR_BITS-1:0] araddr_r;
    logic [AXI_DATA_BITS-1:0] rdata_r;

    typedef enum logic [1:0] {
        READY,
        READ_ADDR,
        WAIT_MEM,
        SEND_RESP
    } state_t;

    state_t PS, NS;

    always_ff @(posedge axi_clk or negedge reset_n) begin
        if (!reset_n)
            PS <= READY;
        else
            PS <= NS;
    end

    // * =======================================================================
    // * CONTROL PATH
    // * =======================================================================

    logic araddr_we;


    always_comb begin
        NS = PS;
        s_axi_arready = 0;
        s_axi_rvalid  = 0;
        s_axi_rresp   = OKAY;
        s_axi_rlast   = 0;

        rd_valid = 0;
        araddr_we = 0;
        waiting = 0;

        case (PS)
            READY: begin
                s_axi_arready = 1;
                if (s_axi_arvalid) begin
                    araddr_we = 1;
                    NS = READ_ADDR;
                end
            end

            READ_ADDR: begin
                rd_valid = 1;
                if (rd_ready_read)
                    NS = WAIT_MEM;
            end

            WAIT_MEM: begin
                waiting = 1;
                if (rd_we)
                    NS = SEND_RESP;
            end

            SEND_RESP: begin
                s_axi_rvalid = 1;
                s_axi_rresp  = OKAY;
                s_axi_rlast  = 1;

                if (s_axi_rready)
                    NS = READY;
            end

            default: NS = READY;
        endcase
    end

    assign s_axi_rdata = s_axi_rvalid ? rdata_r : 32'hdeadbeef;

    // * ==========================================================================
    // * DATA PATH
    // * ==========================================================================
    
    always_ff @(posedge axi_clk or negedge reset_n) begin
        if (!reset_n) begin
            araddr_r <= 'd0;
            rdata_r <= 'd0;
        end else begin
            if (araddr_we)
                araddr_r <= s_axi_araddr;
            
            if (rd_we && PS == WAIT_MEM)
                rdata_r <= rd_data;
        end
    end

    always_comb begin
        rd_addr = rd_valid ? araddr_r : 32'hdeadbeef;
    end


endmodule
`endif