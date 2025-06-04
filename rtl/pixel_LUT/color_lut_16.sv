`ifndef COLOR_LUT_16
`define COLOR_LUT_16
`include "displayConsts.svh"

module color_lut_16 (
    input  logic [3:0] index,                         // 4-bit index for 16 colors
    output logic [COLOR_BITS-1:0] color               // 18-bit RGB color output
    );

    always_comb begin
    case (index)
        4'h0: color = 18'h00000;
        4'h1: color = 18'h00003;
        4'h2: color = 18'h00300;
        4'h3: color = 18'h00303;
        4'h4: color = 18'h03000;
        4'h5: color = 18'h03003;
        4'h6: color = 18'h03100;
        4'h7: color = 18'h03333;
        4'h8: color = 18'h01515;
        4'h9: color = 18'h0151F;
        4'hA: color = 18'h01F15;
        4'hB: color = 18'h01F1F;
        4'hC: color = 18'h03F15;
        4'hD: color = 18'h03F1F;
        4'hE: color = 18'h03F3F;
        4'hF: color = 18'h3ffff;
        default: color = 18'h00000;
    endcase
    end
endmodule

`endif