`include "../../rtl/axi4_itf.sv"

module tb_axi4_comms();

    `ifdef USE_POWER_PINS
        wire VPWR;
        wire VGND;
        assign VPWR=1;
        assign VGND=0;
    `endif
    
    bit reset_n;
    axi4_comms DUT (.*);

    // Tasks
    task reset_dut();
        reset_n = 1'b1;

        #(1 * CLK_PERIOD)
        reset_n = 1'b0;
        #(1 * CLK_PERIOD)
        reset_n = 1'b1;
    endtask

    always begin
        #(CLK_PERIOD/2) 
        clk_50MHz <= ~clk_50MHz;
    end

    initial begin
        $dumpfile("tb_axi4_comms.vcd");
        $dumpvars(0);
    end

    // Tests
    initial begin
        clk_50MHz = 1'b0;
        
        reset_dut();

        check_syncs();

        #(2 * CLK_PERIOD)

        $display("[TESTBENCH] PASSED All tests");
        $finish();
    end



endmodule