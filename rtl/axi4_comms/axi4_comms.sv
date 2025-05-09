`include "axi4_itf.sv"
`include "vga_driver_structs.sv"
`include "displayConsts.sv"
`include "axi4_wr_chan.sv"


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

    // * =======================================================================
    // * CONTROL PATH
    // * =======================================================================

    // * =======================================================================
    // * DATA PATH
    // * =======================================================================
    logic [AXI_ADDR_BITS-1:0] wr_addr, rd_addr;
    logic [AXI_DATA_BITS-1:0] wr_data;

    // write request 
    axi4_wr_chan wr_chan (
        .reset_n            (reset_n),
        .axi_clk            (axi_clk),
        .wr_chan_i          (wr_chan_i),
        .wr_chan_o          (wr_chan_o),
        .wr_addr            (wr_addr),
        .wr_data            (wr_data),
        .wr_valid           ()
    );

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

    // read request
    logic tmp;
    axi4_rd_chan rd_chan (
        .reset_n            (reset_n),
        .axi_clk            (axi_clk),
        .rd_chan_i          (rd_chan_i),
        .rd_chan_o          (rd_chan_o),
        .rd_data            ('ha5),
        .rd_we              (tmp), 
        .rd_addr            (rd_addr),
        .rd_valid           (tmp)
    );

endmodule