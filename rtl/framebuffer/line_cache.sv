`ifndef LINE_CACHE
`define LINE_CACHE

`include "displayConsts.svh"


module line_cache (
    input logic clk_write,
    input logic we,
    input logic [H_CNT_BITS-1:0] wr_addr,
    input logic [(2*COLOR_LUT_BITS)-1:0] wr_data,

    input logic clk_read,
    input logic [H_CNT_BITS-1:0] rd_addr,
    output logic [(2*COLOR_LUT_BITS)-1:0] rd_data
);

    logic [(2*COLOR_LUT_BITS)-1:0] mem [0:(H_VISIBLE_AREA/2)-1];

    always_ff @(posedge clk_write) begin
        if (we)
            mem[wr_addr] <= wr_data;
    end

    always_ff @(posedge clk_read) begin
        rd_data <= mem[rd_addr];
    end

endmodule

`endif