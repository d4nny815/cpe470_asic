`include "common/displayConsts.sv"
`include "common/vgaTimes.sv"

import displayConsts::*;
import vgaTimes::*;


module pixel_addr_lut (
    input  logic [H_BITS-1:0] h_cnt,
    input  logic [V_BITS-1:0] v_cnt,
    output logic [PIXEL_ADDR_BITS-1:0] pixel_addr
    );
    

    logic [PIXEL_ADDR_BITS-1:0] pixel_y;

    pixel_row_rom row_rom (
        .v_cnt(v_cnt),
        .pixel_y(pixel_y)
    );

    // Final pixel address: pixel_y + h_cnt
    logic [PIXEL_ADDR_BITS-1:0] pixel_x;
    always_comb begin
        pixel_x = { {(PIXEL_ADDR_BITS-H_BITS){1'b0}}, h_cnt };

        pixel_addr = pixel_y + pixel_x;
    end
endmodule
