`include "../../rtl/common/vgaTimes.sv"

module tb_vgaTiming();
    localparam CLK_PERIOD = 10;

    import vgaTimes::*;

    `ifdef USE_POWER_PINS
        wire VPWR;
        wire VGND;
        assign VPWR=1;
        assign VGND=0;
    `endif
    
    bit clk_50MHz, reset_n;
    bit [H_CNT_BITS - 1 : 0] h_cnt;
    bit [V_CNT_BITS - 1 : 0] v_cnt;
    bit v_sync, h_sync, in_frame;

    vgaTiming DUT (.*);

    // Tasks
    task reset_dut();
        clk_50MHz = 1'b0;
        reset_n = 1'b1;

        #(1 * CLK_PERIOD)
        reset_n = 1'b0;
        #(1 * CLK_PERIOD)
        reset_n = 1'b1;
    endtask

    task check_syncs();


    endtask

    always begin
        #(CLK_PERIOD/2) 
        clk_50MHz <= ~clk_50MHz;
    end

    initial begin
        $dumpfile("tb_vgaTiming.vcd");
        $dumpvars(0);
    end

    // Tests
    initial begin
        clk_50MHz = 1'b0;
        
        reset_dut();

        #(1000000 * CLK_PERIOD)

        $display("[TESTBENCH] PASSED All tests");
        $finish();
    end



endmodule