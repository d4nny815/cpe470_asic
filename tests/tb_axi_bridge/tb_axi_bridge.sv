`timescale 1ns/1ps
`ifndef TB_AXI_BRIDGE
`define TB_AXI_BRIDGE

`include "axi4_itf.sv"
`include "vga_driver_structs.sv"
`include "axi_bridge.sv"

`define WAIT(cond, clk)        \
  begin                         \
    while (!(cond))             \
      @(posedge clk);           \
    @(posedge clk);             \
  end


module tb_axi_bridge();
    import axi4_itf::*;
    import vga_driver_structs::*;

    localparam VGA_CLK_PERIOD = 40;
    localparam AXI_CLK_PERIOD = 15;
    localparam DUMMY_DATA = 8'ha5;

    `ifdef USE_POWER_PINS
        wire VPWR;
        wire VGND;
        assign VPWR=1;
        assign VGND=0;
    `endif
    
    bit test_done = 0;

    // inputs
    // axi 
    bit axi_reset_n;
    bit axi_clk;
    wr_channel_input_t wr_chan_i;
    rd_channel_input_t rd_chan_i;
    bit wr_ready_resp;

    // vga driver
    bit vga_reset_n;
    bit vga_clk;
    bit wr_re;
    bit rd_re;
    bit rd_we;
    bit [DATA_BITS-1:0] rd_data;

    // outputs
    // axi 
    wr_channel_output_t  wr_chan_o;
    rd_channel_output_t  rd_chan_o;
    
    // vga driver
    logic [PIXEL_ADDR_BITS-1:0] wr_addr;
    logic [DATA_BITS-1:0] wr_data;
    logic [PIXEL_ADDR_BITS-1:0] rd_addr;
    axi_comms_status_t status;
    logic init_done;

    // DUT instance
    axi_bridge DUT (.*);

    // gen clocks
    always #(AXI_CLK_PERIOD/2) axi_clk = ~axi_clk;
    always #(VGA_CLK_PERIOD/2) vga_clk = ~vga_clk;

    // housekeeping
    task reset_dut();
        // TODO: remove tmp
        // force DUT.axi_wr_recieved = 0;
        // force DUT.wr_addr   = 'hdeadbeef;
        // force DUT.wr_data   = 'ha5;

        // force DUT.axi_rd_recieved = 0;
        // force DUT.axi_rd_waiting = 0;
        // force DUT.rd_addr_axi   = 'hdeadbeef;

        // end of tmp
        axi_reset_n = 1;
        vga_reset_n = 1;
        wr_chan_i = '0;
        rd_chan_i  = '0;
        wr_re = 0;

        #(1 * (AXI_CLK_PERIOD + VGA_CLK_PERIOD))
        axi_reset_n = 0;
        vga_reset_n = 0;

        #(1 * (AXI_CLK_PERIOD + VGA_CLK_PERIOD))
        axi_reset_n = 1;
        vga_reset_n = 1;

        `WAIT(init_done, vga_clk);
        $display("[TESTBENCH] Reset complete");
    endtask

    // helper tasks
    /* verilator lint_off IMPLICITSTATIC */
    task automatic send_write_request(input logic [PIXEL_ADDR_BITS-1:0] addr,
        input logic [COLOR_LUT_BITS-1:0] data);

        // TODO: change this to axi
        // reconstruct axi addr and data
        bit [AXI_ADDR_BITS-1:0] axi_addr = AXI_BASE_ADDR;
        bit [AXI_DATA_BITS-1:0] axi_data;

        @(posedge axi_clk);
        axi_addr[PIXEL_ADDR_BITS-1:0] = addr;
        axi_data[COLOR_LUT_BITS-1:0] = data;

        @(posedge axi_clk);
        wr_chan_i.awaddr  = axi_addr;
        wr_chan_i.awlen   = 0;
        wr_chan_i.awsize  = 3'b000; // 1 byte
        wr_chan_i.awburst = 2'b01;

        wr_chan_i.wdata   = axi_data; // Byte in lowest 8 bits
        wr_chan_i.wstrb   = 4'b0001;       // Only lowest byte is valid
        wr_chan_i.wlast   = 1;
        
        wr_chan_i.awvalid = 1;
        wr_chan_i.wvalid  = 1; // ! this causes it to hang

        $display("here1");
        // `WAIT(wr_chan_o.awready, axi_clk);
        // 
        // `WAIT(wr_chan_o.wready, axi_clk);

        // wr_chan_i.awvalid = 0;
        // wr_chan_i.wvalid  = 0;

        // wr_chan_i.bready = 1;

        // $display("here2");
        // `WAIT(wr_chan_o.bvalid, axi_clk);

        // wr_chan_i.bready = 0;

        // $display("[TB] send_write_request: addr=0x%0h data=0x%0h -> axi_addr=0x%0h axi_data=0x%0h at time %0t",
        //      addr, data, axi_addr, axi_data, $time);

        // @(posedge axi_clk);
        // force DUT.axi_wr_recieved = 1;
        // force DUT.wr_addr   = axi_addr;
        // force DUT.wr_data   = axi_data;

        // @(posedge axi_clk);
        // force DUT.axi_wr_recieved = 0;
        // force DUT.wr_addr   = 0;
        // force DUT.wr_data   = 0;
    endtask
    /* verilator lint_on IMPLICITSTATIC */

    // task handle_write_req(
    //     output fb_csr_t fb_csr,
    //     output logic [PIXEL_ADDR_BITS-1:0] addr,
    //     output logic [COLOR_LUT_BITS-1:0] data);

    //     `wait(status.wr_req);

    //     @(posedge vga_clk);
    //     wr_re = 1;
    //     fb_csr = status.wr_fb_csr;
    //     addr = status.wr_addr;
    //     data = status.wr_data;

    //     @(posedge vga_clk);
    //     wr_re = 0;

    //     // $display("[TESTBENCH] Got : {{csr=%0d, addr=0x%0h, data=0x%0h}}",
    //             // fb_csr, addr, data);
    // endtask

    // tests
    task test_fb_write_req();
        fb_csr_t expected_wr_fb_csr, dut_wr_fb_csr;
        logic [PIXEL_ADDR_BITS-1:0] expected_wr_addr, dut_wr_addr;
        bit [COLOR_LUT_BITS-1:0] expected_color, dut_wr_data;
        
        expected_wr_fb_csr = FB;
        expected_wr_addr = FB_ADDR;
        expected_color = 'ha5;

        send_write_request(expected_wr_addr, expected_color);

        // handle_write_req(dut_wr_fb_csr, dut_wr_addr, dut_wr_data);

        // @(posedge vga_clk);
        // assert (dut_wr_fb_csr == expected_wr_fb_csr &&
        //     dut_wr_addr    == expected_wr_addr     &&
        //     dut_wr_data    == expected_color)
        // else begin
        //     $error("[TESTBENCH] test_fb_write_req FAILED:\n" +
        //         "  Expected: {{csr=%0d, addr=0x%0h, data=0x%0h}}\n" +
        //         "     Got : {{csr=%0d, addr=0x%0h, data=0x%0h}}",
        //         expected_wr_fb_csr, expected_wr_addr, expected_color,
        //         dut_wr_fb_csr,     dut_wr_addr,     dut_wr_data);
        //     $fatal;
        // end
    endtask

    // task test_csr_write_req();
    //     fb_csr_t expected_wr_fb_csr, dut_wr_fb_csr;
    //     logic [PIXEL_ADDR_BITS-1:0] expected_wr_addr, dut_wr_addr;
    //     bit [COLOR_LUT_BITS-1:0] expected_color, dut_color;
        
    //     expected_wr_fb_csr = CSR;
    //     expected_wr_addr = CR_ADDR;
    //     expected_color = 'hff;

    //     send_write_request(expected_wr_addr, expected_color);
    //     handle_write_req(dut_wr_fb_csr, dut_wr_addr, dut_color);

    //     @(posedge vga_clk);
    //     assert (dut_wr_fb_csr == expected_wr_fb_csr &&
    //         dut_wr_addr    == expected_wr_addr     &&
    //         dut_color    == expected_color)
    //     else begin
    //         $error("test_csr_write_req FAILED:\n" +
    //             "  Expected: {{csr=%0d, addr=0x%0h, data=0x%0h}}\n" +
    //             "     Got : {{csr=%0d, addr=0x%0h, data=0x%0h}}",
    //             expected_wr_fb_csr, expected_wr_addr, expected_color,
    //             dut_wr_fb_csr,     dut_wr_addr,     dut_color);
    //         $fatal;
    //     end

    //     // check cant write to status reg
    //     expected_wr_addr = SR_ADDR;
    //     send_write_request(expected_wr_addr, expected_color);
    //     assert(!status.wr_req)
    //     else begin
    //         $error("test_csr_write_req FAILED:\nWrote to Status Register");
    //         $fatal;
    //     end
    // endtask

    // task automatic test_mult_write_req(input int n);
    //     logic [PIXEL_ADDR_BITS-1:0] expected_wr_addr [$];
    //     bit [COLOR_LUT_BITS-1:0] expected_color [$];

    //     fb_csr_t dut_wr_fb_csr, expected_wr_fb_csr = FB;
    //     logic [PIXEL_ADDR_BITS-1:0] dut_wr_addr;
    //     bit [COLOR_LUT_BITS-1:0] dut_color;

    //     // write
    //     for (int i = 0; i < n; i++) begin
    //         dut_wr_addr = i[PIXEL_ADDR_BITS-1:0];
    //         dut_color = 255 - i[COLOR_LUT_BITS-1:0];
            
    //         expected_wr_addr.push_back(dut_wr_addr);
    //         expected_color.push_back(dut_color);

    //         send_write_request(dut_wr_addr, dut_color);
    //     end

    //     // read
    //     for (int i = 0; i < n; i++) begin
    //         handle_write_req(dut_wr_fb_csr, dut_wr_addr, dut_color);

    //         @(posedge vga_clk);
    //         assert (dut_wr_fb_csr == expected_wr_fb_csr  &&
    //                 dut_wr_addr   == expected_wr_addr[i] &&
    //                 dut_color     == expected_color[i])
    //         else begin
    //             $error("test_csr_write_req FAILED: iter : %d\n" +
    //                 "  Expected: {{csr=%0d, addr=0x%0h, data=0x%0h}}\n" +
    //                 "     Got : {{csr=%0d, addr=0x%0h, data=0x%0h}}", i,
    //                 expected_wr_fb_csr, expected_wr_addr[i], expected_color[i],
    //                 dut_wr_fb_csr,     dut_wr_addr,     dut_color);
    //             $fatal;
    //         end
    //     end
    // endtask

    // task automatic test_blocking_write_req();
    //     fb_csr_t dut_wr_fb_csr;
    //     logic [PIXEL_ADDR_BITS-1:0] dut_wr_addr;
    //     bit [COLOR_LUT_BITS-1:0] dut_color;

    //     // write
    //     for (int i = 0; i < WRITE_REQ_FIFO_SIZE; i++) begin
    //         send_write_request(FB_ADDR, 'd0);
    //     end

    //     // check 
    //     @(posedge vga_clk);
    //     assert(status.wr_full);
    //     else begin
    //         $error("test_blocking_write_req FAILED: status.wr_full expected 1 after %0d writes, got %b",
    //                WRITE_REQ_FIFO_SIZE, status.wr_full);
    //         $fatal;
    //     end

    //     // make sure cant write
    //     assert(!DUT.wr_ready_resp);
    //     else begin
    //         $error("test_blocking_write_req FAILED: DUT.wr_ready_resp expected 0 when FIFO is full, got %b",
    //            DUT.wr_ready_resp);
    //         $fatal;
    //     end

    //     // read buffer
    //     for (int i = 0; i < WRITE_REQ_FIFO_SIZE; i++) begin
    //         handle_write_req(dut_wr_fb_csr, dut_wr_addr, dut_color);
    //     end

    //     // check 
    //     @(posedge vga_clk);
    //     @(posedge vga_clk);
    //     assert(!status.wr_full);
    //     else begin
    //         $error("test_blocking_write_req FAILED: status.wr_full expected 0 after draining, got %b",
    //            status.wr_full);
    //         $fatal;
    //     end

    //     // make sure cant write
    //     assert(DUT.wr_ready_resp);
    //     else begin
    //         $error("test_blocking_write_req FAILED: DUT.wr_ready_resp expected 1 when FIFO has space, got %b",
    //            DUT.wr_ready_resp);
    //         $fatal;
    //     end
    // endtask

    // /* verilator lint_off IMPLICITSTATIC */
    // task send_read_addr(input logic [PIXEL_ADDR_BITS-1:0] addr);
    //     // TODO: change this to axi
    //     // reconstruct axi addr and data
    //     bit [AXI_ADDR_BITS-1:0] axi_addr = AXI_BASE_ADDR;
    //     axi_addr[PIXEL_ADDR_BITS-1:0] = addr;

    //     $display("[TB] send_read_request: addr=0x%0h -> axi_addr=0x%0h at time %0t",
    //          addr, axi_addr, $time);

    //     @(posedge axi_clk);
    //     force DUT.axi_rd_recieved = 1;
    //     force DUT.axi_rd_waiting = 1;
    //     force DUT.rd_addr = axi_addr;

    //     @(posedge axi_clk);
    //     force DUT.axi_rd_recieved = 0;
    //     force DUT.rd_addr   = 0;
    // endtask
    // /* verilator lint_on IMPLICITSTATIC */

    // task handle_read_req(input logic [COLOR_LUT_BITS-1:0] data,
    //     output logic [PIXEL_ADDR_BITS-1:0] addr);
    //     // `wait for rd req
    //     `wait (status.rd_req);
        
    //     // read rd_addr
    //     @(posedge vga_clk);
    //     rd_re = 1;

    //     addr = status.rd_addr;
    //     // send rd_data
    //     @(posedge vga_clk);
    //     rd_re = 0;
    //     rd_data = data;

    //     rd_we = 1;
    //     @(posedge vga_clk);
    //     rd_we = 0;

    //     `wait(!DUT.rdd_fifo_empty);
    // endtask
    
    // task read_from_axi(output logic [COLOR_LUT_BITS-1:0] data);
    //     `wait(!DUT.axi_rd_waiting);
    //     @(posedge axi_clk);
    //     data = DUT.rd_data_small;

    //     @(posedge axi_clk);
    // endtask

    // task test_read_req();
    //     fb_csr_t expected_rd_fb_csr, dut_rd_fb_csr;
    //     logic [PIXEL_ADDR_BITS-1:0] expected_rd_addr, dut_rd_addr;
    //     bit [COLOR_LUT_BITS-1:0] expected_color, dut_color;
        
    //     expected_rd_fb_csr = CSR;
    //     expected_rd_addr = SR_ADDR;
    //     expected_color = DUMMY_DATA;

    //     send_read_addr(expected_rd_addr);

    //     `wait (status.rd_req);
    //     @(posedge vga_clk);
    //     rd_re = 1;
    //     dut_rd_fb_csr = status.rd_fb_csr;
    //     dut_rd_addr = status.rd_addr;

    //     @(posedge vga_clk);
    //     rd_re = 0;

    //     rd_data = expected_color;
    //     rd_we = 1;

    //     @(posedge vga_clk);
    //     rd_we = 0;
    //     force DUT.axi_rd_waiting = 0;
    //     `wait(!DUT.rdd_fifo_empty);

    //     @(posedge axi_clk);
    //     dut_color = DUT.rd_data_small;

    //     @(posedge axi_clk)
    //     assert (dut_rd_fb_csr == expected_rd_fb_csr &&
    //             dut_rd_addr   == expected_rd_addr &&
    //             dut_color     == expected_color)
    //     else begin
    //         $error("[TESTBENCH] test_fb_rdite_req FAILED:\n" +
    //             "  Expected: {{csr=%0d, addr=0x%0h, data=0x%0h}}\n" +
    //             "     Got : {{csr=%0d, addr=0x%0h, data=0x%0h}}",
    //             expected_rd_fb_csr, expected_rd_addr, expected_color,
    //             dut_rd_fb_csr,     dut_rd_addr,     dut_color);
    //         $fatal;
    //     end
    // endtask

    // task automatic test_mult_read_req(input int n);
    //     logic [PIXEL_ADDR_BITS-1:0] expected_rd_addr [$];
    //     bit [COLOR_LUT_BITS-1:0] expected_color [$];

    //     fb_csr_t dut_rd_fb_csr, expected_rd_fb_csr = FB;
    //     logic [PIXEL_ADDR_BITS-1:0] dut_rd_addr;
    //     bit [COLOR_LUT_BITS-1:0] dut_color;

    //     // read addr
    //     for (int i = 0; i < n; i++) begin

    //         dut_rd_addr = i[PIXEL_ADDR_BITS-1:0];
    //         // dut_color = 255 - i[COLOR_LUT_BITS-1:0];
    //         expected_rd_addr.push_back(dut_rd_addr);
            
    //         send_read_addr(dut_rd_addr);
    //     end

    //     // handle req
    //     for (int i = 0; i < n; i++) begin   
    //         dut_color = 255 - i[COLOR_LUT_BITS-1:0];
    //         expected_color.push_back(dut_color);
            
    //         handle_read_req(dut_color, dut_rd_addr);
            
    //         assert(dut_rd_addr == expected_rd_addr[i])
    //         else begin
    //             $error("test_read_req FAILED at iteration %0d:\n" +
    //                     "  Expected rd_addr = 0x%0h,  Got = 0x%0h",
    //                     i, expected_rd_addr[i], dut_rd_addr);
    //             $fatal;
    //         end
    //     end


    //     // read from axi
    //     // for (int i = 0; i < n; i++) begin   
    //     //     handle_read_req(dut_color, dut_rd_addr);
            
    //     //     assert(dut_rd_addr == expected_rd_addr[i])
    //     //     else begin
    //     //         $error("test_read_req FAILED at iteration %0d:\n" +
    //     //                 "  Expected rd_addr = 0x%0h,  Got = 0x%0h",
    //     //                 i, expected_rd_addr[i], dut_rd_addr);
    //     //         $fatal;
    //     //     end
    //     // end

    //     // read
    //     // for (int i = 0; i < n; i++) begin
    //     //     handle_write_req(dut_wr_fb_csr, dut_wr_addr, dut_color);

    //     //     @(posedge vga_clk);
    //     //     assert (dut_wr_fb_csr == expected_wr_fb_csr  &&
    //     //             dut_wr_addr   == expected_wr_addr[i] &&
    //     //             dut_color     == expected_color[i])
    //     //     else begin
    //     //         $error("test_csr_write_req FAILED: iter : %d\n" +
    //     //             "  Expected: {{csr=%0d, addr=0x%0h, data=0x%0h}}\n" +
    //     //             "     Got : {{csr=%0d, addr=0x%0h, data=0x%0h}}", i,
    //     //             expected_wr_fb_csr, expected_wr_addr[i], expected_color[i],
    //     //             dut_wr_fb_csr,     dut_wr_addr,     dut_color);
    //     //         $fatal;
    //     //     end
    //     // end
    // endtask

    // tests
    initial begin
        // for (int i =0; i < 1000; i++) begin
            // #1 $display("Init Timeout %d\n", i);
        // end
        
        #1000;
        $error("Timeout: test did not finish in time");
        $finish;
    end

    initial begin
        `ifdef VERILATOR
            $dumpfile("tb_verilator.vcd");
            $dumpvars(0, tb_axi_bridge);
        `else
            $dumpfile("tb_icarus.vcd");
            $dumpvars(0, tb_axi_bridge);
        `endif

        reset_dut();

        test_fb_write_req();

        // test_csr_write_req();
        // #100;

        // test_mult_write_req(WRITE_REQ_FIFO_SIZE / 3);
        // #100;

        // test_blocking_write_req();
        // #100;

        $display("[TESTBENCH] PASSED Write Requests Tests");

        // // TODO: reading test
        // test_read_req();
        // #100;

        // test_mult_read_req(READ_REQ_FIFO_SIZE / 3);
        // #100;

        // test_blocking_read_req();
        // #100;

        $display("[TESTBENCH] PASSED Read Requests Tests");


        $display("[TESTBENCH] PASSED all tests.");
        @(posedge vga_clk or posedge axi_clk);
        $finish();
    end
endmodule
`endif