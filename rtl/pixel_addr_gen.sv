// TODO: camille
`ifndef PIXEL_ADDR_GEN
`define PIXEL_ADDR_GEN

`include "displayConsts.svh"
`include "vgaTimes.svh"

module pixel_addr_gen (
    input logic clk,
    input logic rst_n,

    input logic [H_CNT_BITS-1:0] h_cnt,
    input logic [V_CNT_BITS-1:0] v_cnt,
    input logic in_frame, next, 
    output logic [VGA_ADDR_BITS-1:0] pixel_addr,
    output logic [PIXEL_ADDR_BITS-1:0] fb_pixel_addr
    );

    logic [PIXEL_ADDR_BITS-1:0] pixel_base;

    // update pixel_base
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
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
            fb_pixel_addr = pixel_base + {{(PIXEL_ADDR_BITS-H_BITS){1'b0}}, h_cnt};
        end else begin
            fb_pixel_addr = pixel_base;
        end
    end

    always_comb begin
        pixel_addr = in_frame ? {v_cnt, h_cnt} : {v_cnt, {H_CNT_BITS{1'd0}}};
    end
    
endmodule
`endif