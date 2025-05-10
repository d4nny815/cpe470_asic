`ifndef TB_VGA_TIMING
`define TB_VGA_TIMING
`include "vgaTimes.sv"

module tb_vgaTiming();
    localparam CLK_PERIOD = 10;

    import vgaTimes::*;

    `ifdef USE_POWER_PINS
        wire VPWR;
        wire VGND;
        assign VPWR=1;
        assign VGND=0;
    `endif
    
    bit clk, reset_n;
    bit [H_CNT_BITS - 1 : 0] h_cnt;
    bit [V_CNT_BITS - 1 : 0] v_cnt;
    bit v_sync, h_sync, in_frame;

    vgaTiming DUT (.*);

    // Tasks
    task reset_dut();
        clk = 1'b0;
        reset_n = 1'b1;

        #(1 * CLK_PERIOD)
        reset_n = 1'b0;
        #(1 * CLK_PERIOD)
        reset_n = 1'b1;
    endtask

    task automatic check_syncs();
    int errors = 0;

    for (int v = 0; v < vgaTimes::V_WHOLELINE; v++) begin
        for (int h = 0; h < vgaTimes::H_WHOLELINE; h++) begin
            @(posedge clk);

            // in_frame check
            if ((DUT.h_cntr < vgaTimes::H_VISIBLE_AREA) && (DUT.v_cntr < vgaTimes::V_VISIBLE_AREA)) begin
                if (!in_frame) begin
                    $error("[in_frame] Expected 1 at h=%0d v=%0d", DUT.h_cntr, DUT.v_cntr);
                    errors++;
                end
            end else begin
                if (in_frame) begin
                    $error("[in_frame] Expected 0 at h=%0d v=%0d", DUT.h_cntr, DUT.v_cntr);
                    errors++;
                end
            end

            // h_sync active-low check
            if ((DUT.h_cntr >= (vgaTimes::H_VISIBLE_AREA + vgaTimes::H_FRONTPORCH)) &&
                (DUT.h_cntr <  (vgaTimes::H_VISIBLE_AREA + vgaTimes::H_FRONTPORCH + vgaTimes::H_SYNC_PULSE))) begin
                if (h_sync) begin
                    $error("[h_sync] Expected 0 (active-low) at h=%0d v=%0d", DUT.h_cntr, DUT.v_cntr);
                    errors++;
                end
            end else begin
                if (!h_sync) begin
                    $error("[h_sync] Expected 1 (idle) at h=%0d v=%0d", DUT.h_cntr, DUT.v_cntr);
                    errors++;
                end
            end

            // v_sync active-low check
            if ((DUT.v_cntr >= (vgaTimes::V_VISIBLE_AREA + vgaTimes::V_FRONTPORCH)) &&
                (DUT.v_cntr <  (vgaTimes::V_VISIBLE_AREA + vgaTimes::V_FRONTPORCH + vgaTimes::V_SYNC_PULSE))) begin
                if (v_sync) begin
                    $error("[v_sync] Expected 0 (active-low) at h=%0d v=%0d", h_cnt, DUT.v_cntr);
                    errors++;
                end
            end else begin
                if (!v_sync) begin
                    $error("[v_sync] Expected 1 (idle) at h=%0d v=%0d", h_cnt, DUT.v_cntr);
                    errors++;
                end
            end
        end
    end
    endtask



    always begin
        #(CLK_PERIOD/2) 
        clk <= ~clk;
    end

    initial begin
        $dumpfile("tb_vgaTiming.vcd");
        $dumpvars(0);
    end

    // Tests
    initial begin
        clk = 1'b0;
        
        reset_dut();

        check_syncs();

        #(1000 * CLK_PERIOD)

        $display("[TESTBENCH] PASSED All tests");
        $finish();
    end
endmodule

`endif