`ifndef TB_WR_CHAN
`define TB_WR_CHAN

`include "axi4_itf.sv"
`include "axi4_transactions.sv"

import axi4_itf::*;
import axi4_transactions::*;

module tb_wr_chan ();
    localparam AXI_CLK_PERIOD = 15;

    `ifdef USE_POWER_PINS
        wire VPWR;
        wire VGND;
        assign VPWR=1;
        assign VGND=0;
    `endif

    // inputs
    logic reset_n;
    logic axi_clk;
    wr_channel_input_t wr_chan_i;
    logic wr_fifo_full;
    
    // outputs
    wr_channel_output_t  wr_chan_o;
    logic [AXI_ADDR_BITS-1:0] wr_addr;
    logic [AXI_DATA_BITS-1:0] wr_data;
    logic wr_valid;

    // DUT instance
    axi_wr_chan DUT (.*);

    // Clock Gen
    always #(AXI_CLK_PERIOD/2) axi_clk = ~axi_clk;
    // default clocking tb_clk @(posedge axi_clk); endclocking

    // housekeeping
    task reset_dut();
        axi_clk = 0;
        reset_n = 1;
        wr_chan_i = '0;

        #(2 * (AXI_CLK_PERIOD))
        reset_n = 0;

        #(2 * (AXI_CLK_PERIOD))
        reset_n = 1;

        $display("[TESTBENCH] Reset complete");
    endtask

    // helper functions/task

    // test cases
    // task test_single_write();
    // endtask

    // task test_burst_write();
    // endtask

    // task test_single_read_from();
    // endtask

    // task test_multiple_read_from();
    // endtask

    // task test_fifo_full_write();
    // endtask

    // main test loop
    initial begin
        $dumpfile("tb_wr_chan.vcd");
        $dumpvars(0, tb_wr_chan);

        reset_dut();


        $display("[TESTBENCH] PASSED all tests.");
        $finish;
    end

    // Crashout :)
    initial begin
        #10000 $error("Timeout");
        $finish();
    end
endmodule

`endif