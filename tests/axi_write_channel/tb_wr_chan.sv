`ifndef TB_WR_CHAN
`define TB_WR_CHAN

`include "axi4_itf.sv"
// `include "axi4_transactions.sv"

import axi4_itf::*;
// import axi4_transactions::*;

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
    logic not_ready_for_resp;
    
    // outputs
    wr_channel_output_t  wr_chan_o;
    logic [AXI_ADDR_BITS-1:0] wr_addr;
    logic [AXI_DATA_BITS-1:0] wr_data;
    logic wr_valid;

    // DUT instance
    axi_wr_chan DUT (.*);

    // Clock Gen
    always #(AXI_CLK_PERIOD/2) axi_clk = ~axi_clk;

    // housekeeping
    task reset_dut();
        axi_clk = 0;
        reset_n = 1;
        not_ready_for_resp = 0;
        wr_chan_i = '0;

        #(2 * (AXI_CLK_PERIOD))
        reset_n = 0;

        #(2 * (AXI_CLK_PERIOD))
        reset_n = 1;

        $display("[TESTBENCH] Reset complete");
    endtask

    // helper functions/task
    task automatic axi_write_single(
        input logic [31:0] addr,
        input logic [7:0]  data
    );
        // Send address and data
        wr_chan_i.awaddr  = addr;
        wr_chan_i.awlen   = 0;
        wr_chan_i.awsize  = 3'b000; // 1 byte
        wr_chan_i.awburst = 2'b01;
        wr_chan_i.awvalid = 1;

        wr_chan_i.wdata   = {24'b0, data}; // Byte in lowest 8 bits
        wr_chan_i.wstrb   = 4'b0001;       // Only lowest byte is valid
        wr_chan_i.wlast   = 1;
        wr_chan_i.wvalid  = 1;

        // Wait for both aw and w to be accepted
        @(posedge axi_clk);
        wait (wr_chan_o.awready && wr_chan_o.wready);

        // Deassert after handshake
        wr_chan_i.awvalid = 0;
        wr_chan_i.wvalid  = 0;

        // Wait for bvalid and respond with bready
        wr_chan_i.bready = 1;
        wait (wr_chan_o.bvalid);

        @(posedge axi_clk);

        wr_chan_i.bready = 0;

        $display("[AXI WRITE] Wrote 0x%02h to 0x%08h", data, addr);
    endtask

    task check_device(
        input bit [AXI_ADDR_BITS-1:0] expected_wr_addr,
        input bit [AXI_DATA_BITS-1:0] expected_wr_data
        );

        wait(wr_valid);
        assert(!(wr_addr == expected_wr_addr && wr_data == expected_wr_data))
        else begin
            $error("check_device failed:\n  Expected: addr = 0x%08h, data = 0x%08h\n  Got:      addr = 0x%08h, data = 0x%08h",
               expected_wr_addr, expected_wr_data, wr_addr, wr_data);
            $finish();
        end;
    endtask

    // test cases
    
    // Tests to see if the interface completes the write channel transaction
    task test_single_write();
        axi_write_single(AXI_CSR_ADDR, 'd1);
    endtask

    // TODO:
    // task test_burst_write();
    // endtask

    // test to make sure write transaction sent through the correct response 
    task test_single_read_from();
        axi_write_single(AXI_CSR_ADDR, 'd1);
        check_device(AXI_CSR_ADDR, 'd1);
    endtask

    // TODO:
    // task test_multiple_read_from();
    // endtask

    // test to make sure write transaction gets block if fifo was full
    // transaction completes when fifo has room 
    task test_fifo_full_write();
        #(2 * AXI_CLK_PERIOD)
        not_ready_for_resp = 1;

        // Send address and data
        wr_chan_i.awaddr  = AXI_FB_ADDR;
        wr_chan_i.awlen   = 0;
        wr_chan_i.awsize  = 3'b000; // 1 byte
        wr_chan_i.awburst = 2'b01;
        wr_chan_i.awvalid = 1;

        wr_chan_i.wdata   = {24'b0, 8'ha5}; // Byte in lowest 8 bits
        wr_chan_i.wstrb   = 4'b0001;       // Only lowest byte is valid
        wr_chan_i.wlast   = 1;
        wr_chan_i.wvalid  = 1;

        // Wait for both aw and w to be accepted
        @(posedge axi_clk);
        wait (wr_chan_o.awready && wr_chan_o.wready);
        wr_chan_i.awvalid = 0;
        wr_chan_i.wvalid  = 0;

        wr_chan_i.bready = 1;

        // make i dont get back ready
        for (int i = 0; i < 10; i++) begin
            @(posedge axi_clk);

            assert(!wr_chan_o.bvalid)
            else begin
                $error("[FIFO FULL TEST] device shouldnt be ready");
                $finish();
            end
        end

        not_ready_for_resp = 0;
        wait(wr_chan_o.bvalid);

        @(posedge axi_clk);
        wr_chan_i.bready = 0;
    endtask

    // main test loop
    initial begin
        $dumpfile("tb_wr_chan.vcd");
        $dumpvars(0, tb_wr_chan);

        reset_dut();

        test_single_write();

        test_fifo_full_write();

        // TODO: add future tests

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