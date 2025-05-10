`ifndef AXI_TRANS
`define AXI_TRANS

`include "axi4_itf.sv"
import axi4_itf::*;

package axi4_transactions;
    // write from host to dev
    task automatic axi_write_single(
        logic axi_clk,
        inout wr_channel_input_t wr_chan_i,
        inout wr_channel_output_t wr_chan_o,
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
        wr_chan_i.awvalid = 0;
        wr_chan_i.wvalid  = 0;

        // Wait for bvalid and respond with bready
        wr_chan_i.bready = 1;
        wait (wr_chan_o.bvalid);

        @(posedge axi_clk);

        wr_chan_i.bready = 0;

        $display("[AXI WRITE] Wrote 0x%02h to 0x%08h", data, addr);
    endtask

    // read from dev to host
    task automatic axi_read_single(
        logic axi_clk,
        inout rd_channel_input_t rd_chan_i,
        inout rd_channel_output_t rd_chan_o,
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
        rd_chan_i.arvalid = 0;

        // Wait for read data
        rd_chan_i.rready = 1;
        wait (rd_chan_o.rvalid);
        data = rd_chan_o.rdata[7:0]; // Read lowest byte

        @(posedge axi_clk);
        rd_chan_i.rready = 0;

        $display("[AXI READ] Read 0x%02h from 0x%08h", data, addr);
    endtask
endpackage
`endif