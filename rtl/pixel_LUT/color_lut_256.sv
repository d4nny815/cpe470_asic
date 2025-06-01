`timescale 1ns / 1ps
`include "common/displayConsts.sv"

import displayConsts::*;

module color_lut_256 (
    input  logic [7:0] index,                 // 8-bit index
    output logic [17:0] color                 // 18-bit color
);

    function automatic logic [5:0] scale_color(input int level);
        case (level)
            0: return 6'd0;
            1: return 6'd13;
            2: return 6'd25;
            3: return 6'd38;
            4: return 6'd50;
            5: return 6'd63;
            default: return 6'd0;
        endcase
    endfunction

    // Declare all variables outside of always_comb to avoid latch inference
    logic [5:0] r, g, b;
    int i, r_level, g_level, b_level, gray_level;
    logic [7:0] gray8;
    logic [5:0] gray6;
    
    always_comb begin
        // Default initialization of all variables
        r = 6'd0;
        g = 6'd0;
        b = 6'd0;
        i = 0;
        r_level = 0;
        g_level = 0;
        b_level = 0;
        gray_level = 0;
        gray8 = 8'd0;
        gray6 = 6'd0;
        
        if (index < 8'd16) begin
            case (index[3:0])
                4'd0  : color = 18'h00000; // black 
                4'd1  : color = 18'h00003; // blue 
                4'd2  : color = 18'h00300; // green 
                4'd3  : color = 18'h00303; // cyan 
                4'd4  : color = 18'h03000; // red 
                4'd5  : color = 18'h03003; // magenta
                4'd6  : color = 18'h03100; // brown (dark yellow) 
                4'd7  : color = 18'h03333; // light gray 
                4'd8  : color = 18'h01515; // dark gray 
                4'd9  : color = 18'h0151F; // light blue
                4'd10 : color = 18'h01F15; // light green 
                4'd11 : color = 18'h01F1F; // light cyan
                4'd12 : color = 18'h03F15; // light red 
                4'd13 : color = 18'h03F1F; // light magenta 
                4'd14 : color = 18'h03F3F; // yellow 
                4'd15 : color = 18'h3FFFF; // white 
                default: color = 18'h00000;
            endcase
        end else if (index < 8'd232) begin
            // 6x6x6 RGB cube
            // Fix for WIDTHEXPAND: Explicitly cast to 32-bit
            i = int'(index) - 16;
            r_level = i / 36;
            g_level = (i / 6) % 6;
            b_level = i % 6;

            r = scale_color(r_level);
            g = scale_color(g_level);
            b = scale_color(b_level);

            color = {r, g, b};
        end else begin
            // Grayscale range
            // Fix for WIDTHEXPAND: Explicitly cast to 32-bit
            gray_level = int'(index) - 232;
            gray8 = 8'(gray_level * 10 + 8); 
            // Fix for WIDTHTRUNC: Explicitly limit to 6 bits
            gray6 = gray8[7:2]; // convert 8-bit gray to 6-bit by taking top 6 bits

            color = {gray6, gray6, gray6};
        end
    end

endmodule