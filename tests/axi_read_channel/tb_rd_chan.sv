`ifndef TB_RD_CHAN
`define TB_RD_CHAN

`include "axi4_itf.sv"

import axi4_itf::*;

module tb_rd_chan ();
    localparam AXI_CLK_PERIOD = 15;

    `ifdef USE_POWER_PINS
        wire VPWR;
        wire VGND;
        assign VPWR=1;
        assign VGND=0;
    `endif

    localparam TEST_DATA = 32'h1234_5678;

    // inputs
    bit reset_n;
    bit axi_clk;
    rd_channel_input_t rd_chan_i;
    bit rd_we;
    bit rd_ready_read;
    
    // outputs
    rd_channel_output_t  rd_chan_o;
    bit [AXI_ADDR_BITS-1:0] rd_addr;
    bit [AXI_DATA_BITS-1:0] rd_data;
    bit rd_valid;

    // DUT instance
    axi_rd_chan DUT (.*);

    // Clock Gen
    always #(AXI_CLK_PERIOD/2) axi_clk = ~axi_clk;

    // housekeeping
    task reset_dut();
        axi_clk = 0;
        reset_n = 1;
        rd_ready_read = 0;
        rd_chan_i = '0;
        rd_we = 0;

        #(2 * (AXI_CLK_PERIOD))
        reset_n = 0;

        #(2 * (AXI_CLK_PERIOD))
        reset_n = 1;

        $display("[TESTBENCH] Reset complete");
    endtask

    // helper functions/task
    task fake_read (input logic [31:0] data);
        wait (!rd_valid);
        @(posedge axi_clk);
        rd_data = data;
        rd_we = 1;

        @(posedge axi_clk)
        rd_we = 0;
    endtask

    task automatic axi_read_single(
        input logic [31:0] addr,
        output logic [31:0]  data
    );
        // Send read address
        rd_chan_i.araddr  = addr;
        rd_chan_i.arlen   = 0;
        rd_chan_i.arsize  = 3'b000; // 1 byte
        rd_chan_i.arburst = 2'b01;
        rd_chan_i.arvalid = 1;
        rd_chan_i.rready  = 0;

        @(posedge axi_clk);
        wait (rd_chan_o.arready);
        rd_chan_i.arvalid = 0;

        rd_chan_i.rready = 1;

        fake_read(TEST_DATA);

        @(posedge axi_clk)
        wait (rd_chan_o.rvalid);
        data = rd_chan_o.rdata;

        @(posedge axi_clk);
        rd_chan_i.rready = 0;

        $display("[AXI READ] Read 0x%02h from 0x%08h", data, addr);
    endtask

    task automatic check_device(input logic [AXI_DATA_BITS-1:0] dut_rd_data);
        assert(dut_rd_data == TEST_DATA)
        else begin
            $error("HELP");
            $finish();
        end
    endtask

    // test cases
    
    // Tests to see if the interface completes the write channel transaction
    task test_single_read();
        logic [AXI_DATA_BITS-1] tmp;
        axi_read_single(AXI_CSR_ADDR, tmp);
    endtask

    // TODO:
    // task test_burst_read();
    // endtask

    // test to make sure read transaction sent through the correct response 
    task test_single_read_from();
        logic [AXI_DATA_BITS-1] tmp;
        axi_read_single(AXI_CSR_ADDR, tmp);
        check_device(tmp);
    endtask

    // TODO:
    // task test_multiple_read_from();
    // endtask

    // test to make sure read transaction gets block if fifo was full
    // transaction completes when fifo has room 
    task test_fifo_full_read();
        logic [31:0] data;

        #(2 * AXI_CLK_PERIOD)
        rd_ready_read = 1;

        // Send read address
        rd_chan_i.araddr  = AXI_FB_ADDR;
        rd_chan_i.arlen   = 0;
        rd_chan_i.arsize  = 3'b000; // 1 byte
        rd_chan_i.arburst = 2'b01;
        rd_chan_i.arvalid = 1;
        rd_chan_i.rready  = 0;

        @(posedge axi_clk);
        wait (rd_chan_o.arready);
        rd_chan_i.arvalid = 0;

        rd_chan_i.rready = 1;

        // make sure i dont get back ready
        for (int i = 0; i < 10; i++) begin
            @(posedge axi_clk);

            assert(rd_valid)
            else begin
                $error("[FIFO FULL TEST] wrote to full FIFO");
                $finish();
            end
        end

        rd_ready_read = 0;

        fake_read(TEST_DATA);

        @(posedge axi_clk)
        wait (rd_chan_o.rvalid);
        data = rd_chan_o.rdata;

        @(posedge axi_clk);
        rd_chan_i.rready = 0;

    endtask

    task test_wait_for_mem();
        logic [31:0] data;

        #(2 * AXI_CLK_PERIOD)
        rd_we = 0;

        // Send read address
        rd_chan_i.araddr  = AXI_FB_ADDR;
        rd_chan_i.arlen   = 0;
        rd_chan_i.arsize  = 3'b000; // 1 byte
        rd_chan_i.arburst = 2'b01;
        rd_chan_i.arvalid = 1;
        rd_chan_i.rready  = 0;

        @(posedge axi_clk);
        wait (rd_chan_o.arready);
        rd_chan_i.arvalid = 0;

        rd_chan_i.rready = 1;

        @(posedge axi_clk)
        wait (!rd_valid);

        // make sure i dont get back ready
        for (int i = 0; i < 10; i++) begin
            @(posedge axi_clk);

            assert(!rd_chan_o.rvalid)
            else begin
                $error("[FIFO FULL TEST]");
                $finish();
            end
        end

        rd_data = TEST_DATA;
        rd_we = 1;

        @(posedge axi_clk)
        wait (rd_chan_o.rvalid);
        data = rd_chan_o.rdata;

        @(posedge axi_clk);
        rd_chan_i.rready = 0;

        @(posedge axi_clk);
    endtask

    // main test loop
    initial begin
        $dumpfile("tb_rd_chan.vcd");
        $dumpvars(0, tb_rd_chan);

        reset_dut();

        test_single_read();

        test_fifo_full_read();

        test_wait_for_mem();


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