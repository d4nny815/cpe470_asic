`include "axi4_itf.sv"
`include "vga_driver_structs.sv"

import axi4_itf::*;
import vga_driver_structs::*;
import displayConsts::*;

module axi4_wr_chan (
    input logic reset_n,
    input logic axi_clk,
    input wr_channel_input_t wr_chan_i,
    output wr_channel_output_t  wr_chan_o,
    output logic [AXI_ADDR_BITS-1:0] wr_addr,
    output logic [AXI_DATA_BITS-1:0] wr_data,
    output logic wr_valid
    );


    // * =======================================================================
    // * CONTROL PATH
    // * =======================================================================

    typedef enum logic [1:0] {
        READY,
        VALID,
        WAIT_RESP
    } state_t;
    state_t PS, NS;

    always_ff @(posedge axi_clk or negedge reset_n) begin
        if (!reset_n) PS <= READY;
        else PS <= NS;
    end

    logic wr_addr_we, wr_data_we;
    always_comb begin
        NS = PS;
        wr_chan_o = 'd0;
        wr_valid = 1'b0;
        wr_addr_we = 1'b0;
        wr_data_we = 1'b0;

        case (PS)
            READY: begin
                wr_chan_o.awready = 1;
                wr_chan_o.wready = 1;
                if ((wr_chan_i.awvalid && wr_chan_o.awready) &&
                    (wr_chan_i.wvalid && wr_chan_o.wready)) begin 
                    wr_addr_we = 1'b1;
                    wr_data_we = 1'b1;
                    NS = VALID;
                end
                else
                    NS = READY;
            end
            
            VALID: begin
                wr_valid = 1;
                NS = WAIT_RESP;
            end

            WAIT_RESP: begin
                wr_chan_o.bvalid = 1'b1;
                wr_chan_o.bresp  = OKAY;

                if (wr_chan_i.bready) NS = READY;
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
                awaddr_r <= wr_addr_we ? wr_chan_i.awaddr : 0;
                wdata_r <= wr_data_we ? wr_chan_i.wdata : 0;
        end
    end

    always_comb begin
        wr_addr = awaddr_r;
        wr_data = wdata_r;
    end


endmodule