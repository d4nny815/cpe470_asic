`include "axi4_itf.sv"
`include "vga_driver_structs.sv"

module tb_axi4_comms();
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
    
    // inputs
    // axi 
    bit reset_n;
    bit axi_clk;
    wr_channel_input_t wr_chan_i;
    rd_channel_input_t rd_chan_i;

    // vga driver
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
    bit init_done;

    axi4_comms DUT (.*);

    // write from host to dev
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
        wait (wr_chan_o.awready && wr_chan_o.wready);

        // Deassert after handshake
        @(posedge axi_clk);
        @(negedge axi_clk);
        wr_chan_i.awvalid = 0;
        wr_chan_i.wvalid  = 0;

        // Wait for bvalid and respond with bready
        wr_chan_i.bready = 1;
        wait (wr_chan_o.bvalid);

        @(posedge axi_clk);
        @(negedge axi_clk);

        wr_chan_i.bready = 0;

        $display("[AXI WRITE] Wrote 0x%02h to 0x%08h", data, addr);
    endtask

    // read from dev to host
    task automatic axi_read_single(
        input  logic [31:0] addr,
        output logic [7:0]  data
    );
        // Send read address
        rd_chan_i.araddr  = addr;
        rd_chan_i.arlen   = 0;
        rd_chan_i.arsize  = 3'b000; // 1 byte
        rd_chan_i.arburst = 2'b01;
        rd_chan_i.arvalid = 1;
        rd_chan_i.rready  = 0;

        // Wait for address handshake
        wait (rd_chan_o.arready);
        @(posedge axi_clk);
        @(negedge axi_clk);
        rd_chan_i.arvalid = 0;

        // Wait for read data
        rd_chan_i.rready = 1;
        wait (rd_chan_o.rvalid);
        data = rd_chan_o.rdata[7:0]; // Read lowest byte

        @(posedge axi_clk);
        @(negedge axi_clk);
        rd_chan_i.rready = 0;

        $display("[AXI READ] Read 0x%02h from 0x%08h", data, addr);
    endtask

    // gen clocks
    always #(VGA_CLK_PERIOD/2) vga_clk = ~vga_clk;
    always #(AXI_CLK_PERIOD/2) axi_clk = ~axi_clk;

    task reset_dut();
        axi_clk = 0;
        vga_clk = 0;
        reset_n = 1;
        wr_chan_i = '0;
        rd_chan_i  = '0;

        #(1 * VGA_CLK_PERIOD)
        reset_n = 0;
        #(1 * VGA_CLK_PERIOD)
        reset_n = 1;
        wait (init_done == 1'b1);
        $display("[TESTBENCH] Reset complete");
    endtask

    // tests
    logic [7:0] rdata;
    initial begin
        $dumpfile("tb_axi4_comms.vcd");
        $dumpvars(0, tb_axi4_comms);

        reset_dut();

        // axi_write_single(AXI_CSR_ADDR, 8'hA5);
        axi_read_single(AXI_CSR_ADDR, rdata);
        $display("[TESTBENCH] Read value: 0x%02h", rdata);
        assert (rdata == 8'hA5) else $fatal("[ERROR] AXI readback mismatch");

        $display("[TESTBENCH] PASSED all tests.");
        $finish;
    end

    initial #1000 $error("Timeout");



endmodule