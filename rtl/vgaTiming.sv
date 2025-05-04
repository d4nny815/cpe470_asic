`include "common/vgaTimes.sv"
`include "common/displayConsts.sv"

import displayConsts::*;

module vgaTiming (
    input wire clk_50MHz,
    input wire reset_n,
    output reg [H_CNT_BITS - 1 : 0] h_cnt,
    output reg h_sync,
    output reg [V_CNT_BITS - 1 : 0] v_cnt,
    output reg v_sync,
    output reg in_frame
    );

    import vgaTimes::*;

    reg v_en;
    reg [H_BITS : 0] h_cntr;
    reg [V_BITS : 0] v_cntr;

    always_ff @(posedge clk_50MHz) begin
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

    always_comb begin
        h_cnt = h_cntr[H_CNT_BITS - 1 : 0];
        v_cnt = v_cntr[V_CNT_BITS - 1 : 0];
        
        h_sync = !(h_cntr >= H_VISIBLE_AREA + H_FRONTPORCH && 
                    h_cntr < H_VISIBLE_AREA + H_FRONTPORCH + H_SYNC_PULSE);
        v_sync = !(v_cntr >= V_VISIBLE_AREA + V_FRONTPORCH && 
                    v_cntr < V_VISIBLE_AREA + V_FRONTPORCH + V_SYNC_PULSE);
        
        in_frame = h_cntr < H_VISIBLE_AREA && v_cntr < V_VISIBLE_AREA;
        
        v_en = h_cntr == H_WHOLELINE - 1;
    end

endmodule