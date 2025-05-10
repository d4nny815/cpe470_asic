// TODO: camille
`include "common/displayConsts.sv"
`include "common/vgaTimes.sv"

import displayConsts::*;
import vgaTimes::*;

module pixel_addr_gen (
    input logic clk,
    input logic rst,

    input logic [H_BITS-1:0] h_cnt,
    input logic [V_BITS-1:0] v_cnt,
    input logic in_frame, next, 
    output logic [PIXEL_ADDR_BITS-1:0] pixel_addr
    );

    logic [PIXEL_ADDR_BITS-1:0] pixel_base;

    // update pixel_base
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_base <= 0;
        end else if (next && !in_frame) begin
            if (v_cnt == V_VISIBLE_AREA - 1) begin
                pixel_base <= 0;
            end else begin
                pixel_base <= pixel_base + H_VISIBLE_AREA;
            end
        end
    end

    // output pixel_addr
    always_comb begin
        if (in_frame) begin
            pixel_addr = pixel_base + {{(9){1'b0}}, h_cnt};
        end else begin
            pixel_addr = 0;
        end
    end
    
endmodule
