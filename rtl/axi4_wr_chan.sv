`include "axi4_itf.sv"
`include "vga_driver_structs.sv"

import axi4_itf::*;
import vga_driver_structs::*;
import displayConsts::*;

module axi4_wr_chan (
    input logic axi_clk,
    input wr_channel_input_t wr_chan_i,
    output wr_channel_output_t  wr_chan_o,
    output logic [AXI_ADDR_BITS-1:0] wr_addr,
    output logic [AXI_DATA_BITS-1:0] wr_data
    output logic wr_valid;
    );


    // * ==========================================================================
    // * CONTROL PATH
    // * ==========================================================================

    typedef enum data_type {
        IDLE,
        SINGLE,
        BURST,
        
    } state_t ;

    // * ==========================================================================
    // * DATA PATH
    // * ==========================================================================

endmodule