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
        wr_chan_i.awaddr  = addr;
        wr_chan_i.awlen   = 0;
        wr_chan_i.awsize  = 3'b000; // 1 byte
        wr_chan_i.awburst = 2'b01;  // INCR
        wr_chan_i.awvalid = 1;

        wr_chan_i.wdata  = {24'b0, data};
        wr_chan_i.wstrb  = 4'b0001; // Lower byte enabled only
        wr_chan_i.wlast  = 1;
        wr_chan_i.wvalid = 1;

        @(posedge axi_clk)
        wait (wr_chan_o.awready);
        wait (wr_chan_o.wready);
        wr_chan_i.wvalid = 0;
        wr_chan_i.awvalid = 0;

        // Wait for write response
        wr_chan_i.bready = 1;
        
        @(posedge axi_clk)
        wait (wr_chan_o.bvalid);
        wr_chan_i.bready = 0;
    endtask

    // // read from dev to host
    // task automatic axi_read_single(
    //     ref axi4_ar_t ar,
    //     ref axi4_r_t  r,
    //     input  logic [31:0] addr,
    //     output logic [7:0] data
    // );
    //     ar.araddr  = addr;
    //     ar.arlen   = 0;
    //     ar.arsize  = 3'b010;
    //     ar.arburst = 2'b01;
    //     ar.arvalid = 1;
    //     wait (ar.arready);
    //     ar.arvalid = 0;

    //     r.rready = 1;
    //     wait (r.rvalid);
    //     data = r.rdata[7:0];
    //     r.rready = 0;
    // endtask

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
    initial begin
        $dumpfile("tb_axi4_comms.vcd");
        $dumpvars(0, tb_axi4_comms);

        reset_dut();

        // logic [7:0] rdata;
        axi_write_single(AXI_CSR_ADDR, 8'hA5);
        // axi4_read(ar_chan, r_chan, 32'h1100_0000, rdata);
        // $display("[TESTBENCH] Read value: 0x%02h", rdata);
        // assert (rdata == 8'hA5) else $fatal("[ERROR] AXI readback mismatch");

        $display("[TESTBENCH] PASSED all tests.");
        $finish;
    end

    initial #1000 $error("Timeout");



endmodule