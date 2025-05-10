`ifndef AXI_WR_CHAN
`define AXI_WR_CHAN
`include "axi4_itf.sv"
`include "vga_driver_structs.sv"

import axi4_itf::*;
import vga_driver_structs::*;
import displayConsts::*;

module axi4_wr_chan (
    input logic reset_n,
    input logic axi_clk,
    input wr_channel_input_t wr_chan_i,
    input logic wr_fifo_full,
    output wr_channel_output_t  wr_chan_o,
    output logic [AXI_ADDR_BITS-1:0] wr_addr,
    output logic [AXI_DATA_BITS-1:0] wr_data,
    output logic wr_valid
    );

    logic wr_addr_we, wr_data_we;


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

    logic awready_r, wready_r, bvalid_r;
    BRESP_t bresp_r;
    
    logic awvalid_ready, wvalid_ready, b_ready;
    assign awvalid_ready = wr_chan_i.awvalid && awready_r;
    assign wvalid_ready  = wr_chan_i.wvalid && wready_r;
    assign b_ready = wr_chan_i.bready;

    assign wr_chan_o.awready = awready_r;
    assign wr_chan_o.wready  = wready_r;
    assign wr_chan_o.bvalid  = bvalid_r;
    assign wr_chan_o.bresp   = bresp_r;

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
                if (awvalid_ready && wvalid_ready) begin 
                    wr_addr_we = 1'b1;
                    wr_data_we = 1'b1;
                    NS = VALID;
                end
                else
                    NS = READY;
            end
            
            VALID: begin
                wr_valid = 1;
                if (!wr_fifo_full)
                    NS = WAIT_RESP;
                else
                    NS = VALID;
            end

            WAIT_RESP: begin
                bvalid_r = 1'b1; // need to change when full
                bresp_r  = OKAY;

                if (b_ready) NS = READY;
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
                    awaddr_r <= wr_chan_i.awaddr;
                else
                    awaddr_r <= 0;

                if (wr_data_we)
                    wdata_r <= wr_chan_i.wdata;
                else
                    wdata_r <= 0;
        end
    end

    always_comb begin
        wr_addr = awaddr_r;
        wr_data = wdata_r;
    end


endmodule

`endif