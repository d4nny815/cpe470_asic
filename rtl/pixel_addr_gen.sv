`include "common/displayConsts.sv"
`include "common/vgaTimes.sv"

import displayConsts::*;
import vgaTimes::*;

// TODO: camille
module pixel_addr_gen (
    input logic [H_BITS-1:0] h_cnt,
    input logic [V_BITS-1:0] v_cnt,
    input logic in_frame, next, 
    output logic [PIXEL_ADDR_BITS-1:0] pixel_addr
    );
    
    assign pixel_addr = 0;
endmodule
