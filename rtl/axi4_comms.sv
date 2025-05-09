// TODO: danny
`include "axi4_itf.sv"
`include "vga_driver_structs.sv"

import axi4_itf::*;
import vga_driver_structs::*;

module axi4_comms (
    input logic reset_n,
    
    // axi channels
    input logic axi_clk,
    input axi4_aw_t aw_chan,
    input axi4_w_t  w_chan,
    output axi4_b_t  b_chan,
    input axi4_ar_t ar_chan,
    output axi4_r_t  r_chan,
    
    // design channels
    input logic vga_clk,
    input logic wr_re,
    input logic rd_re,
    input logic [DATA_BITS-1:0] rd_data,
    output axi_comms_status_t status
    );

endmodule