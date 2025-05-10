`ifndef AXI_RD_CHAN
`define AXI_RD_CHAN
`include "axi4_itf.sv"
`include "vga_driver_structs.sv"

import axi4_itf::*;
import vga_driver_structs::*;
import displayConsts::*;

module axi_rd_chan (
    input logic reset_n,
    input logic axi_clk,
    input rd_channel_input_t rd_chan_i,
    output rd_channel_output_t  rd_chan_o,
    input logic rd_we, 
    input logic [AXI_DATA_BITS-1:0] rd_data,
    input logic rd_ready_read,
    output logic [AXI_ADDR_BITS-1:0] rd_addr,
    output logic rd_valid
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

    //
    logic araddr_we;
    logic arvalid_ready, rvalid;
    logic arready_r, rvalid_r, rresp_r, rlast_r, rready_r;
    
    assign rready_r = rd_chan_i.rready;
    assign arvalid_ready = rd_chan_i.arvalid && arready_r;

    assign rd_chan_o.arready = arready_r;
    assign rd_chan_o.rvalid  = rvalid_r;
    assign rd_chan_o.rresp   = rresp_r;
    assign rd_chan_o.rlast   = rlast_r;
    assign rd_chan_o.rdata   = rvalid_r ? rdata_r : 32'hdeadbeef;


    always_comb begin
        NS = PS;
        arready_r = 0;
        rvalid_r  = 0;
        rresp_r   = 0;
        rlast_r   = 0;

        rd_valid = 0;
        araddr_we = 0;

        case (PS)
            READY: begin
                arready_r = 1;
                if (arvalid_ready) begin
                    araddr_we = 1;
                    NS = READ_ADDR;
                end
            end

            READ_ADDR: begin
                rd_valid = 1;
                if (!rd_ready_read) 
                    NS = WAIT_MEM;
            end

            WAIT_MEM: begin
                if (rd_we)
                    NS = SEND_RESP;
            end

            SEND_RESP: begin
                rvalid_r = 1;
                rresp_r  = OKAY;
                rlast_r  = 1;

                if (rready_r)
                    NS = READY;
            end

            default: NS = READY;
        endcase
    end

    // * ==========================================================================
    // * DATA PATH
    // * ==========================================================================
    
    always_ff @(posedge axi_clk or negedge reset_n) begin
        if (!reset_n) begin
            araddr_r <= 'd0;
            rdata_r <= 'd0;
        end else begin
            if (araddr_we)
                araddr_r <= rd_chan_i.araddr;
            
            if (rd_we)
                rdata_r <= rd_data ;
        end
    end

    always_comb begin
        rd_addr = rd_valid ? araddr_r : 32'hdeadbeef;
    end


endmodule
`endif