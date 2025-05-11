`ifndef TB_AXI_BRIDGE
`define TB_AXI_BRIDGE

`include "axi4_itf.sv"
`include "vga_driver_structs.sv"

module tb_axi_bridge();
    import axi4_itf::*;
    import vga_driver_structs::*;

    localparam VGA_CLK_PERIOD = 40;
    localparam AXI_CLK_PERIOD = 15;

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
    axi_comms_status_t status;
    logic init_done;

    // DUT instance
    axi_bridge DUT (.*);

    // gen clocks
    // VGA clock
    initial begin
        vga_clk = 0;
        forever #(VGA_CLK_PERIOD/2) vga_clk = ~vga_clk;
    end

    // AXI clock
    initial begin
        axi_clk = 0;
        forever #(AXI_CLK_PERIOD/2) axi_clk = ~axi_clk;
    end

    // housekeeping
    task reset_dut();
        
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

        wait (init_done == 1'b1);
        $display("[TESTBENCH] Reset complete");

        #(3 * (AXI_CLK_PERIOD + VGA_CLK_PERIOD));
    endtask

    // helper tasks
    task automatic axi_write_single(
        input logic [31:0] addr,
        input logic [7:0]  data
    );

        int timeout = 100;

        @(posedge axi_clk);

        wr_chan_i.awaddr  = addr;
        wr_chan_i.awlen   = 0;
        wr_chan_i.awsize  = 3'b000; // 1 byte
        wr_chan_i.awburst = 2'b01;
        wr_chan_i.awvalid = 1;

        wr_chan_i.wdata   = {24'b0, data}; // Byte in lowest 8 bits
        wr_chan_i.wstrb   = 4'b0001;       // Only lowest byte is valid
        wr_chan_i.wlast   = 1;
        wr_chan_i.wvalid  = 1;
        
        // ! DANNY FIX THIS
        // FIXME: why goes it hang here
        while (!(wr_chan_o.awready && wr_chan_o.wready) && timeout > 0) begin
            @(posedge axi_clk);
            timeout--;
            $display("  waiting… awready=%b wready=%b  timeout=%0d",
                    wr_chan_o.awready, wr_chan_o.wready, timeout);
        end

        if (timeout == 0) begin
            $error("AXI write address/data handshake timed out!");
            $fatal;
        end

        @(posedge axi_clk);
        wr_chan_i.awvalid = 0;
        wr_chan_i.wvalid  = 0;
        $display("AXI write accepted at time %0t", $time);
        $fatal();


        // wait (!wr_chan_o.awready && !wr_chan_o.wready);
        $error("ENDED PROPERLY");

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

    // task automatic read_write_req(
    //     output bit [(PIXEL_ADDR_BITS + COLOR_LUT_BITS + 1)-1:0] dut_packet
    //     );
    
    //     @(posedge vga_clk)
    //     wait (status.wr_req);
    //     wr_re = 1'b1;

    //     @(posedge vga_clk)
    //     wr_re = 1'b0;
    //     dut_packet = {status.wr_fb_csr, status.wr_addr, status.wr_data};
    // endtask

    // tests
    task test_fb_write_req();
        logic [PIXEL_ADDR_BITS-1:0] expected_wr_addr;
        fb_csr_t expected_wr_fb_csr;
        logic [COLOR_LUT_BITS-1:0] expected_wr_data;
        
        bit [COLOR_LUT_BITS-1:0] expected_color;
        expected_wr_addr = AXI_FB_ADDR[PIXEL_ADDR_BITS-1:0];
        expected_color = 'ha5;
        expected_wr_fb_csr = FB;
        axi_write_single(AXI_FB_ADDR, expected_color);

        // output bit [(PIXEL_ADDR_BITS + COLOR_LUT_BITS + 1)-1:0] expected_packet;
        // expected_packet = {expected_wr_fb_csr, expected_wr_addr, expected_color}

        // read from device side

        // wait(!status.wr_req);
        $display("End of test_fb_write_req");
    endtask

//     task wr_multiple_test(input int n);
//         bit [COLOR_LUT_BITS-1:0] expected_color, color;
//         bit [(PIXEL_ADDR_BITS + COLOR_LUT_BITS + 1)-1:0] expected_packet;

//         logic [PIXEL_ADDR_BITS-1:0] expected_wr_addr, dut_wr_addr;
//         fb_csr_t expected_wr_fb_csr, dut_wr_fb_csr;
//         logic [COLOR_LUT_BITS-1:0] expected_wr_data, dut_wr_data;
        
//         int addr_temp;
        

//         for (int i = 0; i < n; i++) begin
//             expected_color = i[COLOR_LUT_BITS-1:0];
//             axi_write_single(AXI_FB_ADDR + i, expected_color);
//         end

//         for (int i = 0; i < n; i++) begin
//             addr_temp = AXI_FB_ADDR + i;
//             expected_wr_addr = addr_temp[PIXEL_ADDR_BITS-1:0];
//             expected_color = i[COLOR_LUT_BITS-1:0];
//             expected_wr_fb_csr = FB;

//             wr_re = 1'b1;
//             @(posedge vga_clk)

//             wr_re = 1'b0;
//             assert (status.wr_addr == expected_wr_addr &&
//                     status.wr_fb_csr == expected_color &&
//                     status.wr_data == expected_wr_fb_csr)
//             else begin 
//                 $error("DIDNT READ CORRECTLY ex: %h !== dut: %h @ %h",
//                 {expected_wr_fb_csr, expected_wr_addr, expected_color}, 
//                 {status.wr_data, status.wr_addr, status.wr_fb_csr}, 
//                 i);
//                 $finish();
//             end
//         end
        
//         wait(!status.wr_req);
//     endtask


    // tests
    initial begin
        #100000;
        if (!test_done) begin
            $error("Timeout: test did not finish in time");
            $finish;
        end
    end

    initial begin
        $dumpfile("tb_axi_bridge.vcd");
        $dumpvars(0, tb_axi_bridge);

        reset_dut();

        test_fb_write_req();

        $display("[TESTBENCH] PASSED all tests.");

        test_done = 1;
        #10;
        $finish();
    end
endmodule

    

`endif