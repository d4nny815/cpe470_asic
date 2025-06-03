`ifndef VGA_TIMING
`define VGA_TIMING

`include "vgaTimes.svh"
`include "displayConsts.svh"

module vga_timing (
    input wire clk,
    input wire reset_n,
    output reg [H_CNT_BITS - 1 : 0] h_cnt,
    output reg h_sync,
    output reg [V_CNT_BITS - 1 : 0] v_cnt,
    output reg v_sync,
    output reg in_frame
    );

    reg v_en;
    reg [H_BITS : 0] h_cntr;
    reg [V_BITS : 0] v_cntr;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            h_cntr <= 'd0;
            v_cntr <= 'd0;
        end 
        
        else if (h_cntr == H_WHOLELINE - 1) begin
            h_cntr <= 'd0;
        end
        else begin
            h_cntr <= h_cntr + 1;
        end
        
        if (v_en) begin
            if (v_cntr == V_WHOLELINE - 1) begin
                v_cntr <= 'd0;
            end
            else begin
                v_cntr <= v_cntr + 1;
            end
        end
    end

    assign h_cnt = h_cntr[H_CNT_BITS: 1];
    assign v_cnt = v_cntr[V_CNT_BITS: 1];

    always_comb begin
        h_sync = !(h_cntr >= _H_VISIBLE_AREA + H_FRONTPORCH && 
                    h_cntr < _H_VISIBLE_AREA + H_FRONTPORCH + H_SYNC_PULSE);
        v_sync = !(v_cntr >= _V_VISIBLE_AREA + V_FRONTPORCH && 
                    v_cntr < _V_VISIBLE_AREA + V_FRONTPORCH + V_SYNC_PULSE);
        
        in_frame = h_cntr < _H_VISIBLE_AREA && v_cntr < _V_VISIBLE_AREA;
        
        v_en = h_cntr == H_WHOLELINE - 1;
    end

endmodule
`endif