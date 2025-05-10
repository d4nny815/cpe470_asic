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
    input logic [AXI_DATA_BITS-1:0] rd_data,
    input logic rd_we, 
    output logic [AXI_ADDR_BITS-1:0] rd_addr,
    output logic rd_valid
    );

    logic [AXI_ADDR_BITS-1:0] araddr_r;
    logic [AXI_DATA_BITS-1:0] rdata_r;

    // * =======================================================================
    // * CONTROL PATH
    // * =======================================================================

    typedef enum logic [1:0] {
        READY,
        WAIT_MEM,
        SEND_RESP
    } state_t;
    state_t PS, NS;

    always_ff @(posedge axi_clk or negedge reset_n) begin
        if (!reset_n) PS <= READY;
        else PS <= NS;
    end

    logic araddr_we;
    always_comb begin
        NS = PS;
        rd_chan_o.arready = 0;
        rd_chan_o.rvalid  = 0;
        rd_chan_o.rdata   = 0;
        rd_chan_o.rresp   = 0;
        rd_chan_o.rlast   = 0;

        rd_valid = 0;
        araddr_we = 0;

        case (PS)
            READY: begin
                rd_chan_o.arready = 1;
                if (rd_chan_i.arvalid && rd_chan_o.arready) begin
                    araddr_we = 1;
                    NS = WAIT_MEM;
                end
            end

            WAIT_MEM: begin
                rd_valid = 1;
                if (rd_we)
                    NS = SEND_RESP;
            end

            SEND_RESP: begin
                rd_chan_o.rvalid = 1;
                rd_chan_o.rdata  = rdata_r;
                rd_chan_o.rresp  = OKAY;
                rd_chan_o.rlast  = 1;

                if (rd_chan_i.rready)
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
            araddr_r <= 'hdeadbeef;
        end else begin
            araddr_r <= araddr_we ? rd_chan_i.araddr : 0;
            rdata_r <= rd_we ? rd_data : 0;
        end
    end

    always_comb begin
        rd_addr = araddr_r;
    end


endmodule
`endif