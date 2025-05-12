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
        // TODO: remove tmp
        force DUT.axi_wr_recieved = 0;
        force DUT.wr_addr   = 'hdeadbeef;
        force DUT.wr_data   = 'ha5;
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

        wait (init_done);
        wait (!status.wr_full);
        $display("[TESTBENCH] Reset complete");

        #(3 * (AXI_CLK_PERIOD + VGA_CLK_PERIOD));
    endtask

    // helper tasks
    task send_write_request(input logic [PIXEL_ADDR_BITS-1:0] addr,
        input logic [COLOR_LUT_BITS-1:0] data);

        // TODO: change this to axi
        // reconstruct axi addr and data
        bit [AXI_ADDR_BITS-1:0] axi_addr = AXI_BASE_ADDR;
        bit [AXI_DATA_BITS-1:0] axi_data;
        axi_addr[PIXEL_ADDR_BITS-1:0] = addr;
        axi_data[COLOR_LUT_BITS-1:0] = data;

        // $display("[TB] send_write_request: addr=0x%0h data=0x%0h -> axi_addr=0x%0h axi_data=0x%0h at time %0t",
            //  addr, data, axi_addr, axi_data, $time);

        @(posedge axi_clk);
        force DUT.axi_wr_recieved = 1;
        force DUT.wr_addr   = axi_addr;
        force DUT.wr_data   = axi_data;

        @(posedge axi_clk);
        force DUT.axi_wr_recieved = 0;
        force DUT.wr_addr   = 0;
        force DUT.wr_data   = 0;
    endtask

    task read_write_request(
        output fb_csr_t fb_csr,
        output logic [PIXEL_ADDR_BITS-1:0] addr,
        output logic [COLOR_LUT_BITS-1:0] data);

        wait(status.wr_req);

        @(posedge vga_clk);
        wr_re = 1;

        @(posedge vga_clk);
        wr_re = 0;
        fb_csr = status.wr_fb_csr;
        addr = status.wr_addr;
        data = status.wr_data;
    endtask

    // tests
    task test_fb_write_req();
        fb_csr_t expected_wr_fb_csr, dut_wr_fb_csr;
        logic [PIXEL_ADDR_BITS-1:0] expected_wr_addr, dut_wr_addr;
        bit [COLOR_LUT_BITS-1:0] expected_color, dut_wr_data;
        
        expected_wr_fb_csr = FB;
        expected_wr_addr = FB_ADDR;
        expected_color = 'ha5;

        send_write_request(expected_wr_addr, expected_color);

        read_write_request(dut_wr_fb_csr, dut_wr_addr, dut_wr_data);

        assert (dut_wr_fb_csr == expected_wr_fb_csr &&
            dut_wr_addr    == expected_wr_addr     &&
            dut_wr_data    == expected_color)
        else begin
            $error("test_fb_write_req FAILED:\n" +
                "  Expected: {{csr=%0d, addr=0x%0h, data=0x%0h}}\n" +
                "     Got : {{csr=%0d, addr=0x%0h, data=0x%0h}}",
                expected_wr_fb_csr, expected_wr_addr, expected_color,
                dut_wr_fb_csr,     dut_wr_addr,     dut_wr_data);
            $fatal;
        end
    endtask

    task test_csr_write_req();
        fb_csr_t expected_wr_fb_csr, dut_wr_fb_csr;
        logic [PIXEL_ADDR_BITS-1:0] expected_wr_addr, dut_wr_addr;
        bit [COLOR_LUT_BITS-1:0] expected_color, dut_color;
        
        expected_wr_fb_csr = CSR;
        expected_wr_addr = CR_ADDR;
        expected_color = 'hff;

        send_write_request(expected_wr_addr, expected_color);
        read_write_request(dut_wr_fb_csr, dut_wr_addr, dut_color);

        assert (dut_wr_fb_csr == expected_wr_fb_csr &&
            dut_wr_addr    == expected_wr_addr     &&
            dut_color    == expected_color)
        else begin
            $error("test_csr_write_req FAILED:\n" +
                "  Expected: {{csr=%0d, addr=0x%0h, data=0x%0h}}\n" +
                "     Got : {{csr=%0d, addr=0x%0h, data=0x%0h}}",
                expected_wr_fb_csr, expected_wr_addr, expected_color,
                dut_wr_fb_csr,     dut_wr_addr,     dut_color);
            $fatal;
        end

        // check cant write to status reg
        expected_wr_addr = SR_ADDR;
        send_write_request(expected_wr_addr, expected_color);
        assert(!status.wr_req)
        else begin
            $error("test_csr_write_req FAILED:\nWrote to Status Register");
            $fatal;
        end

    endtask

    task test_mult_write_req(input int n);
        logic [PIXEL_ADDR_BITS-1:0] expected_wr_addr [$];
        bit [COLOR_LUT_BITS-1:0] expected_color [$];

        fb_csr_t dut_wr_fb_csr, expected_wr_fb_csr = FB;
        logic [PIXEL_ADDR_BITS-1:0] dut_wr_addr;
        bit [COLOR_LUT_BITS-1:0] dut_color;

        // write
        for (int i = 0; i < n; i++) begin
            dut_wr_addr = i[PIXEL_ADDR_BITS-1:0];
            dut_color = 255 - i[COLOR_LUT_BITS-1:0];
            
            expected_wr_addr.push_back(dut_wr_addr);
            expected_color.push_back(dut_color);

            send_write_request(dut_wr_addr, dut_color);
        end

        // read
        for (int i = 0; i < n; i++) begin
            read_write_request(dut_wr_fb_csr, dut_wr_addr, dut_color);

            assert (dut_wr_fb_csr == expected_wr_fb_csr  &&
                    dut_wr_addr   == expected_wr_addr[i] &&
                    dut_color     == expected_color[i])
            else begin
                $error("test_csr_write_req FAILED: iter : %d\n" +
                    "  Expected: {{csr=%0d, addr=0x%0h, data=0x%0h}}\n" +
                    "     Got : {{csr=%0d, addr=0x%0h, data=0x%0h}}", i,
                    expected_wr_fb_csr, expected_wr_addr[i], expected_color[i],
                    dut_wr_fb_csr,     dut_wr_addr,     dut_color);
                $fatal;
            end
        end
    endtask

    task test_block_write_req();
        fb_csr_t dut_wr_fb_csr;
        logic [PIXEL_ADDR_BITS-1:0] dut_wr_addr;
        bit [COLOR_LUT_BITS-1:0] dut_color;

        // write
        for (int i = 0; i < WRITE_REQ_FIFO_SIZE; i++) begin
            send_write_request(FB_ADDR, 'd0);
        end

        // check 
        @(posedge vga_clk);
        @(posedge vga_clk);
        assert(status.wr_full);
        else begin
            $error("test_block_write_req FAILED: status.wr_full expected 1 after %0d writes, got %b",
                   WRITE_REQ_FIFO_SIZE, status.wr_full);
            $fatal;
        end

        // make sure cant write
        assert(!DUT.wr_ready_resp);
        else begin
            $error("test_block_write_req FAILED: DUT.wr_ready_resp expected 0 when FIFO is full, got %b",
               DUT.wr_ready_resp);
            $fatal;
        end

        // read buffer
        for (int i = 0; i < WRITE_REQ_FIFO_SIZE; i++) begin
            read_write_request(dut_wr_fb_csr, dut_wr_addr, dut_color);
        end

        // check 
        @(posedge vga_clk);
        @(posedge vga_clk);
        assert(!status.wr_full);
        else begin
            $error("test_block_write_req FAILED: status.wr_full expected 0 after draining, got %b",
               status.wr_full);
            $fatal;
        end

        // make sure cant write
        assert(DUT.wr_ready_resp);
        else begin
            $error("test_block_write_req FAILED: DUT.wr_ready_resp expected 1 when FIFO has space, got %b",
               DUT.wr_ready_resp);
            $fatal;
        end
    endtask


    // tests
    initial begin
        #1000000;
        if (!test_done) begin
            $error("Timeout: test did not finish in time");
            $finish;
        end
    end

    initial begin
        $dumpfile("tb_axi_bridge.vcd");
        $dumpvars(0, tb_axi_bridge);

        reset_dut();
        #50;

        test_fb_write_req();
        #100;

        test_csr_write_req();
        #100;

        test_mult_write_req(WRITE_REQ_FIFO_SIZE / 3);
        #100;

        test_block_write_req();
        #100;

        $display("[TESTBENCH] PASSED all tests.");

        test_done = 1;
        #100;
        $finish();
    end
endmodule

    

`endif