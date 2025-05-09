`include "common/displayConsts.sv"

import displayConsts::*;

// TODO: camille
module pixel_lut (
    input logic [COLOR_LUT_BITS-1:0] index,
    output logic [COLOR_BITS-1:0] color 
    );

    assign color = 0;

endmodule