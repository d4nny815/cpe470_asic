`ifndef TB_RD_CHAN
`define TB_RD_CHAN

`include "axi4_itf.sv"
`include "vga_driver_structs.sv"
`include "axi_rd_chan.sv"

import axi4_itf::*;
import vga_driver_structs::*;

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
    bit waiting;

    // DUT instance
    axi_rd_chan DUT (.*);

    // Clock Gen
    always #(AXI_CLK_PERIOD/2) axi_clk = ~axi_clk;

    // housekeeping
    task reset_dut();
        axi_clk = 0;
        reset_n = 1;
        rd_ready_read = 1;
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
        wait(waiting);
        @(posedge axi_clk);
        rd_data = data;
        rd_we = 1;

        @(posedge axi_clk)
        rd_we = 0;
    endtask

    task automatic axi_read_single(
        input logic [31:0] addr,
        output logic [31:0]  data);
        
        @(posedge axi_clk);
        rd_chan_i.araddr  = addr;
        rd_chan_i.arlen   = 0;
        rd_chan_i.arsize  = 3'b000; // 1 byte
        rd_chan_i.arburst = 2'b01;
        rd_chan_i.arvalid = 1;
        rd_chan_i.rready  = 0;

        wait (rd_chan_o.arready);
        @(posedge axi_clk);
        rd_chan_i.arvalid = 0;
        rd_chan_i.rready = 1;

        fake_read(TEST_DATA);

        wait (rd_chan_o.rvalid);
        wait (DUT.PS == 0);
        @(posedge axi_clk)
        
        data = rd_chan_o.rdata;
    endtask

    // test cases
    
    // tests to see if the interface completes the write channel transaction
    task test_single_read();
        logic [AXI_DATA_BITS-1:0] tmp;
        axi_read_single(AXI_CSR_ADDR, tmp);
    endtask

    // test to make sure read transaction gets block if fifo was full
    // transaction completes when fifo has room 
    task test_fifo_full_read();
        @(posedge axi_clk);
        rd_ready_read = 0;

        rd_chan_i.araddr  = AXI_FB_ADDR;
        rd_chan_i.arlen   = 0;
        rd_chan_i.arsize  = 3'b000; // 1 byte
        rd_chan_i.arburst = 2'b01;
        rd_chan_i.arvalid = 1;
        rd_chan_i.rready  = 0;

        wait(!rd_chan_o.arready);
        @(posedge axi_clk);

        // make sure i dont get back ready
        for (int i = 0; i < 10; i++) begin
            @(posedge axi_clk);
            assert(rd_valid)
            else begin
                $error("[FIFO FULL TEST] wrote to full FIFO %d", rd_valid);
                $finish();
            end
        end

        @(posedge axi_clk);
        rd_ready_read = 1;

        rd_chan_i.arvalid = 0;
        rd_chan_i.rready = 1;

        fake_read(TEST_DATA);

        wait (rd_chan_o.rvalid);
        wait (DUT.PS == 0);
        @(posedge axi_clk);

    endtask

    task test_wait_for_mem();
        logic [31:0] data;

        #(2 * AXI_CLK_PERIOD)

        @(posedge axi_clk);
        rd_ready_read = 1;

        rd_chan_i.araddr  = AXI_FB_ADDR;
        rd_chan_i.arlen   = 0;
        rd_chan_i.arsize  = 3'b000; // 1 byte
        rd_chan_i.arburst = 2'b01;
        rd_chan_i.arvalid = 1;
        rd_chan_i.rready  = 0;

        wait(!rd_chan_o.arready);
        @(posedge axi_clk);
        rd_chan_i.arvalid = 0;
        rd_chan_i.rready = 1;

        // wait for mem here
        for (int i = 0; i < 10; i++) begin
            @(posedge axi_clk);

            assert(waiting)
            else begin
                $error("[WAIT FOR MEM] Should be waiting for mem");
                $finish();
            end
        end

        @(posedge axi_clk);
        rd_data = TEST_DATA;
        rd_we = 1;

        wait (!waiting);
        wait (rd_chan_o.rvalid);
        
        @(posedge axi_clk);
        wait (DUT.PS == 0);
        rd_chan_i.rready = 0;
        rd_we = 0;

        @(posedge axi_clk);

        #100;

    endtask

    // main test loop
    initial begin
        
        `ifdef VERILATOR
            $dumpfile("tb_verilator.vcd");
            $dumpvars(0, tb_rd_chan);
        `else
            $dumpfile("tb_icarus.vcd");
            $dumpvars(0, tb_rd_chan);
        `endif

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
        #1000 $error("Timeout");
        $finish();
    end
endmodule

`endif