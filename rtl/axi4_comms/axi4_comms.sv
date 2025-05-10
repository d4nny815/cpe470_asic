`include "axi4_itf.sv"
`include "vga_driver_structs.sv"
`include "displayConsts.sv"
`include "axi4_wr_chan.sv"
`include "axi4_rd_chan.sv"
`include "ASYNC_FIFO.sv"


// ! DONT KNOW if it works for proper AXI read/write
// ! TESTED with my own vip  

import axi4_itf::*;
import vga_driver_structs::*;
import displayConsts::*;

module axi4_comms (
    // axi channels
    input logic axi_reset_n,
    input logic axi_clk,
    input wr_channel_input_t wr_chan_i,
    input rd_channel_input_t rd_chan_i,
    output wr_channel_output_t  wr_chan_o,
    output rd_channel_output_t  rd_chan_o,
    
    // design channels
    input logic vga_reset_n,
    input logic vga_clk,
    input logic wr_re,
    input logic rd_re,
    input logic rd_we,
    input logic [DATA_BITS-1:0] rd_data,
    output axi_comms_status_t status,
    output logic init_done
    );

    assign init_done = axi_reset_n;

    // * =======================================================================
    // * CONTROL PATH
    // * =======================================================================
    logic wr_fifo_we_i, wr_fifo_empty;
    // write request
    // always_comb begin 

    // end

    // * =======================================================================
    // * DATA PATH
    // * =======================================================================
    logic [AXI_ADDR_BITS-1:0] wr_addr, rd_addr;
    logic [AXI_DATA_BITS-1:0] wr_data;

    // write request 
    axi4_wr_chan wr_chan (
        .reset_n            (axi_reset_n),
        .axi_clk            (axi_clk),
        .wr_chan_i          (wr_chan_i),
        .wr_chan_o          (wr_chan_o),
        .wr_addr            (wr_addr),
        .wr_data            (wr_data),
        .wr_valid           (wr_fifo_we_i)
    );

    // write packet encoder
    typedef struct packed {
        fb_csr_t fb_csr;
        logic [PIXEL_ADDR_BITS-1:0] addr;
        logic [COLOR_LUT_BITS-1:0] data;
    } wr_fifo_packet_t;

    logic wr_fifo_valid_packet;
    wr_fifo_packet_t wr_fifo_data_i, wr_fifo_data_o;
    logic [PIXEL_ADDR_BITS-1:0] wr_addr_sliced;
    logic [COLOR_LUT_BITS-1:0] wr_data_sliced;

    assign wr_addr_sliced = wr_addr[PIXEL_ADDR_BITS-1:0];
    assign wr_data_sliced = wr_data[COLOR_LUT_BITS-1:0];

    always_comb begin
        wr_fifo_data_i.addr = wr_addr_sliced;
        wr_fifo_data_i.data = wr_data_sliced;
        if (wr_addr_sliced < CSR_ADDR_OFFSET)
            wr_fifo_data_i.fb_csr = FB;
        else
            wr_fifo_data_i.fb_csr = CSR;
        
        wr_fifo_valid_packet = (wr_addr < FRAME_SIZE || 
                            (wr_addr >= AXI_CSR_ADDR && wr_addr <= AXI_CSR_ADDR + 1));
    end
        
    ASYNC_FIFO #( 
        .DSIZE($bits(wr_fifo_packet_t)),
        .ASIZE(4)
    ) wr_fifo (
        .rrst_n     (vga_reset_n),         // Read increment, read clock, read reset
        .rclk       (vga_clk), 
        .rinc       (wr_re), 
        .wdata      (wr_fifo_data_i),      // Input data - data to be written
        .wrst_n     (axi_reset_n),         // Write increment, write clock, write reset
        .wclk       (axi_clk), 
        .winc       (wr_fifo_we_i), 
        .rdata      (wr_fifo_data_o),      // Output data - data to be read
        .rempty     (wr_fifo_empty),       // Read empty signal
        .wfull      (status.wr_full)       // Write full signal
    );

    assign status.wr_req     = !wr_fifo_empty;
    assign status.wr_fb_csr  = wr_fifo_data_o.fb_csr;
    assign status.wr_addr    = wr_fifo_data_o.addr;
    assign status.wr_data    = wr_fifo_data_o.data;

    // read request
    // logic tmp;
    // axi4_rd_chan rd_chan (
    //     .reset_n            (axi_reset_n),
    //     .axi_clk            (axi_clk),
    //     .rd_chan_i          (rd_chan_i),
    //     .rd_chan_o          (rd_chan_o),
    //     .rd_data            ('ha5),
    //     .rd_we              (tmp), 
    //     .rd_addr            (rd_addr),
    //     .rd_valid           (tmp)
    // );

    

endmodule