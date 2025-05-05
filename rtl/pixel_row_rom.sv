`include "common/displayConsts.sv"
`include "common/vgaTimes.sv"

import displayConsts::*;
import vgaTimes::*;

module pixel_row_rom (
    input  logic [V_BITS-1:0] v_cnt,
    output logic [PIXEL_ADDR_BITS-1:0] pixel_y
    );

    logic [PIXEL_ADDR_BITS-1:0] rom [0:V_VISIBLE_AREA-1];

    initial 
    `ifdef VERILATOR
        $readmemh("../../rtl/mem/pixel_row.mem", rom);
    `else
        $readmemh("mem/pixel_row.mem", rom);
    `endif


    assign pixel_y = (v_cnt < V_VISIBLE_AREA) ? rom[v_cnt] : '0;
endmodule
