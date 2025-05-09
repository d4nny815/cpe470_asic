`include "axi4_itf.sv"
`include "vga_driver_structs.sv"
`include "displayConsts.sv"


// ! currently only supports single writes

import axi4_itf::*;
import vga_driver_structs::*;
import displayConsts::*;

module axi4_comms (
    input logic reset_n,
    
    // axi channels
    input logic axi_clk,
    input wr_channel_input_t wr_chan_i,
    input rd_channel_input_t rd_chan_i,
    output wr_channel_output_t  wr_chan_o,
    output rd_channel_output_t  rd_chan_o,
    
    // design channels
    input logic vga_clk,
    input logic wr_re,
    input logic rd_re,
    input logic rd_we,
    input logic [DATA_BITS-1:0] rd_data,
    output axi_comms_status_t status,
    output logic init_done
    );

    assign init_done = reset_n;

    logic wr_chan_rdy2accpt; // !wr_fifo_full

    // * ==========================================================================
    // * WRITE CONTROL
    // * ==========================================================================
    
    logic wr_valid;
    logic bvalid;

    always_ff @(posedge axi_clk or negedge reset_n) begin
        if (!reset_n) begin
            wr_valid <= 0;
            bvalid   <= 0;
        end else begin
            if (wr_chan_i.awvalid && wr_chan_rdy2accpt &&
                wr_chan_i.wvalid  && wr_chan_rdy2accpt) begin
                wr_valid <= 1;
                bvalid   <= 1;
            end else if (!wr_chan_rdy2accpt && wr_chan_i.bready) begin
                wr_valid <= 0;
                bvalid   <= 0;
            end
        end
    end

    always_comb begin
        wr_chan_o.bvalid = bvalid;
        wr_chan_o.bresp  = OKAY;

        wr_chan_o.awready = wr_chan_rdy2accpt;
        wr_chan_o.wready  = wr_chan_rdy2accpt;
    end

    // * ==========================================================================
    // * COMBINATIONAL STROBES
    // * ==========================================================================

    logic wr_addr_we, wr_data_we;
    always_comb begin
        wr_chan_rdy2accpt = reset_n; // TODO: implement
        wr_addr_we = wr_chan_i.awvalid && wr_chan_rdy2accpt;
        wr_data_we = wr_chan_i.wvalid  && wr_chan_rdy2accpt;
    end

    // * ==========================================================================
    // * WRITE DATA PATH
    // * ==========================================================================
    logic [AXI_ADDR_BITS-1:0] wr_addr;
    logic [AXI_DATA_BITS-1:0] wr_data;

    always_ff @(posedge axi_clk or negedge reset_n) begin
        if (!reset_n) begin
            wr_addr <= 'hdeadbeef;
            wr_data <= 'hdeadbeef;
        end else begin
            if (wr_addr_we)
                wr_addr <= wr_chan_i.awaddr;

            if (wr_data_we)
                wr_data <= wr_chan_i.wdata;
        end
    end

    // write packet encoder
    typedef struct packed {
        logic [PIXEL_ADDR_BITS-1:0] addr;
        logic [COLOR_LUT_BITS-1:0] data;
        fb_csr_t fb_csr;
    } wr_fifo_packet_t;

    logic wr_fifo_valid_packet;
    wr_fifo_packet_t wr_fifo_data_i;
    always_comb begin
        wr_fifo_data_i.addr = wr_addr[PIXEL_ADDR_BITS-1:0];
        wr_fifo_data_i.data = wr_data[COLOR_LUT_BITS-1:0];
        wr_fifo_data_i.fb_csr = wr_addr[PIXEL_ADDR_BITS-1:0] < CSR_ADDR_OFFSET ? FB : CSR;
        wr_fifo_valid_packet = (wr_addr < FRAME_SIZE || 
                            (wr_addr >= CSR_ADDR_OFFSET && wr_addr <= CSR_ADDR_OFFSET + 1));
    end
        
    // TODO: write wr_fifo_data_i to fifo 


endmodule