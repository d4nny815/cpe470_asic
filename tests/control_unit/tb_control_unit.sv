`timescale 1ns / 1ps

`include "displayConsts.sv"
`include "vga_driver_structs.sv"
`include "control_unit.sv"

import vga_driver_structs::*;

module tb_control_unit();
    // Clock and reset signals
    logic clk;
    
    // DUT interface signals - flattened
    logic fb_valid;
    logic cr;
    
    // Status signals
    logic RST_N;
    logic in_frame;
    logic axi_wr_full;
    logic axi_wr_req;
    fb_csr_t axi_wr_fb_csr;
    logic axi_rd_full;
    logic axi_rd_req;
    fb_csr_t axi_rd_fb_csr;
    
    // Control signals
    logic ctrl_reset_n;
    logic ctrl_next;
    logic ctrl_vga_fetch;
    logic ctrl_wr_ld;
    logic ctrl_rd_ld;
    logic ctrl_cr_ld;
    logic ctrl_fb_w_r;
    logic ctrl_fb_en;
    logic ctrl_wr_re;
    logic ctrl_rd_re;
    logic ctrl_rd_we;
    logic [1:0] ctrl_rd_data_sel;
    logic addr_sel;
    
    // Test control signals
    int test_case;
    string test_name;
    int errors;
    
    // Instantiate the DUT
    control_unit dut (
        .clk(clk),
        .fb_valid(fb_valid),
        .cr(cr),
        
        // Status signals
        .RST_N(RST_N),
        .in_frame(in_frame),
        .axi_wr_full(axi_wr_full),
        .axi_wr_req(axi_wr_req),
        .axi_wr_fb_csr(axi_wr_fb_csr),
        .axi_rd_full(axi_rd_full),
        .axi_rd_req(axi_rd_req),
        .axi_rd_fb_csr(axi_rd_fb_csr),
        
        // Control signals
        .ctrl_reset_n(ctrl_reset_n),
        .ctrl_next(ctrl_next),
        .ctrl_vga_fetch(ctrl_vga_fetch),
        .ctrl_wr_ld(ctrl_wr_ld),
        .ctrl_rd_ld(ctrl_rd_ld),
        .ctrl_cr_ld(ctrl_cr_ld),
        .ctrl_fb_w_r(ctrl_fb_w_r),
        .ctrl_fb_en(ctrl_fb_en),
        .ctrl_wr_re(ctrl_wr_re),
        .ctrl_rd_re(ctrl_rd_re),
        .ctrl_rd_we(ctrl_rd_we),
        .ctrl_rd_data_sel(ctrl_rd_data_sel),
        .addr_sel(addr_sel)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end

    initial begin
        // Name as needed
        $dumpfile("tb_control_unit.vcd");
        $dumpvars(0);
    end
    
    // Test sequence
    initial begin
        // Initialize test environment
        errors = 0;
        test_case = 0;
        RST_N = 0;
        fb_valid = 0;
        cr = 0;
        
        // Initialize all control signals
        in_frame = 1;
        axi_wr_full = 0;
        axi_wr_req = 0;
        axi_wr_fb_csr = FB;
        axi_rd_full = 0;
        axi_rd_req = 0;
        axi_rd_fb_csr = FB;
        
        // Apply reset
        #10 RST_N = 1;
        #10;
        
        // Test FSM 1: VGA Timing Controller
        //test_fsm1();
        
        // Test FSM 2: Read/Write Controller
        test_fsm2();
        
        // Report results
        if (errors == 0)
            $display("All tests passed! (%0d test cases)", test_case);
        else
            $display("Tests completed with %0d errors in %0d test cases", errors, test_case);
            
        $finish;
    end
    
    // Task to test FSM 1 (VGA Timing Controller)
    task test_fsm1();
        // Test case 1: Verify INFRAME -> OUTFRAME transition and next signal
        begin_test_case("FSM1: INFRAME -> OUTFRAME transition and next signal");
        in_frame = 1; // Start in frame
        @(posedge clk);
        
        // Verify we're in INFRAME state
        if (ctrl_next != 0 || ctrl_vga_fetch != 0) begin
            $display("Error: Expected next=0, vga_fetch=0 in INFRAME state");
            errors++;
        end
        
        // Trigger transition to OUTFRAME
        in_frame = 0;
        @(posedge clk);
        
        // Check next is asserted during transition
        if (ctrl_next != 1) begin
            $display("Error: Expected next=1 during INFRAME->OUTFRAME transition");
            errors++;
        end
        
        @(posedge clk);
        
        // Check we're now in OUTFRAME state with fetch asserted
        if (ctrl_vga_fetch != 1 || ctrl_next != 0) begin
            $display("Error: Expected vga_fetch=1 and next = 0 in OUTFRAME state");
            errors++;
        end
        end_test_case();
        
        // Test case 2: Verify OUTFRAME -> INFRAME transition and fetch signal
        begin_test_case("FSM1: OUTFRAME -> INFRAME transition and fetch signal");
        in_frame = 0; // Start out of frame
        @(posedge clk);
        
        // Verify we're in OUTFRAME state with fetch asserted
        if (ctrl_vga_fetch != 1 || ctrl_next != 0) begin
            $display("Error: Expected vga_fetch=1 and next = 0 in OUTFRAME state");
            errors++;
        end
        
        // Trigger transition to INFRAME
        in_frame = 1;
        @(posedge clk);
        
        // Check fetch is deasserted and next is not asserted
        if (ctrl_vga_fetch != 0 || ctrl_next != 0) begin
            $display("Error: Expected vga_fetch=0, next=0 after transition to INFRAME");
            errors++;
        end
        end_test_case();
    endtask
    
    // Task to test FSM 2 (Read/Write Controller)
    task test_fsm2();
        // Reset before starting FSM2 tests
        RST_N = 0;
        @(posedge clk);
        RST_N = 1;
        @(posedge clk);
        
        // Test case 3: Write to Frame Buffer
        begin_test_case("FSM2: Write to Frame Buffer");
        // Assert write request
        axi_wr_req = 1;
        @(posedge clk);
        
        // Check wr_re is asserted
        if (ctrl_wr_re != 1) begin
            $display("Error: Expected wr_re=1 after write request");
            errors++;
        end
        
        // Deassert write request
        axi_wr_req = 0;
        
        // Set write FIFO not full
        axi_wr_full = 0;
        @(posedge clk);
        
        // Check wr_ld is asserted
        if (ctrl_wr_ld != 1) begin
            $display("Error: Expected wr_ld=1 when FIFO not full");
            errors++;
        end
        
        // Set write to frame buffer
        axi_wr_fb_csr = FB;
        @(posedge clk);
        
        // Check addr_sel
        if (addr_sel != 0) begin
            $display("Error: Expected addr_sel=0 for frame buffer write");
            errors++;
        end
        
        // Wait for frame buffer valid
        fb_valid = 0;
        @(posedge clk);
        
        // Assert frame buffer valid
        fb_valid = 1;
        @(posedge clk);
        
        // Check frame buffer write signals
        if (ctrl_fb_w_r != 1 || ctrl_fb_en != 1) begin
            $display("Error: Expected fb_w_r=1, fb_en=1 for frame buffer write");
            errors++;
        end
        
        // Should return to IDLE
        @(posedge clk);
        end_test_case();
        
        // Test case 4: Write to Control Register
        begin_test_case("FSM2: Write to Control Register");
        // Assert write request
        axi_wr_req = 1;
        @(posedge clk);
        
        // Deassert write request
        axi_wr_req = 0;
        
        // Set write FIFO not full and target CSR
        axi_wr_full = 0;
        axi_wr_fb_csr = CSR;
        @(posedge clk);
        
        // Check cr_ld signal
        if (ctrl_cr_ld != 1) begin
            $display("Error: Expected cr_ld=1 for control register write");
            errors++;
        end
        
        // Should return to IDLE
        @(posedge clk);
        end_test_case();
        
        // Test case 5: Read from Frame Buffer
        begin_test_case("FSM2: Read from Frame Buffer");
        fb_valid = 0;
        // Assert read request
        axi_rd_req = 1;
        @(posedge clk);
        
        // Check rd_re is asserted
        if (ctrl_rd_re != 1) begin
            $display("Error: Expected rd_re=1 after read request");
            errors++;
        end
        
        // Deassert read request
        axi_rd_req = 0;
        
        // Set read FIFO not full and target frame buffer
        axi_rd_full = 0;
        axi_rd_fb_csr = FB;
        @(posedge clk);
        
        // Check rd_ld is asserted
        if (ctrl_rd_ld != 1) begin
            $display("Error: Expected rd_ld=1 when FIFO not full");
            errors++;
        end
        
        // Check addr_sel for read address
        @(posedge clk);
        if (addr_sel != 1) begin
            $display("Error: Expected addr_sel=1 for frame buffer read");
            errors++;
        end
        
        // Wait for frame buffer valid
        @(posedge clk);
        
        // Assert frame buffer valid
        fb_valid = 1;
        @(posedge clk);
        
        // Check frame buffer read signals
        if (ctrl_fb_w_r != 0 || ctrl_fb_en != 1 || ctrl_rd_we != 1 || ctrl_rd_data_sel != 2'b01) begin
            $display("Error: Expected fb_w_r=0, fb_en=1, rd_we=1, rd_data_sel=01 for frame buffer read");
            errors++;
        end
        
        // Should return to IDLE
        @(posedge clk);
        end_test_case();
        
        // Test case 6: Read from Control Register
        begin_test_case("FSM2: Read from Control Register");
        // Assert read request
        axi_rd_req = 1;
        @(posedge clk);
        
        // Deassert read request
        axi_rd_req = 0;
        
        // Set read FIFO not full, target CSR, and cr=1
        axi_rd_full = 0;
        axi_rd_fb_csr = CSR;
        cr = 1;
        @(posedge clk);
        
        // Check read data selector
        if (ctrl_rd_data_sel != 2'b10 || ctrl_rd_we != 1) begin
            $display("Error: Expected rd_data_sel=10, rd_we=1 for control register read");
            errors++;
        end
        
        // Should return to IDLE
        @(posedge clk);
        end_test_case();
        
        // Test case 7: Read from Status Register
        begin_test_case("FSM2: Read from Status Register");
        // Assert read request
        axi_rd_req = 1;
        @(posedge clk);
        
        // Deassert read request
        axi_rd_req = 0;
        
        // Set read FIFO not full, target CSR, and cr=0
        axi_rd_full = 0;
        axi_rd_fb_csr = CSR;
        cr = 0;
        @(posedge clk);
        
        // Check read data selector
        if (ctrl_rd_data_sel != 2'b11 || ctrl_rd_we != 1) begin
            $display("Error: Expected rd_data_sel=11, rd_we=1 for status register read");
            errors++;
        end
        
        // Should return to IDLE
        @(posedge clk);
        end_test_case();
        
        // Test case 8: Write FIFO Full Handling
        begin_test_case("FSM2: Write FIFO Full Handling");
        // Assert write request
        axi_wr_req = 1;
        @(posedge clk);
        
        // Deassert write request but set write FIFO full
        axi_wr_req = 0;
        axi_wr_full = 1;
        @(posedge clk);
        
        // It should stay in WRITE_WAIT state with no wr_ld asserted
        if (ctrl_wr_ld != 0) begin
            $display("Error: Expected wr_ld=0 when FIFO is full");
            errors++;
        end
        
        // Now clear the full flag
        axi_wr_full = 0;
        @(posedge clk);
        
        // Now it should assert wr_ld
        if (ctrl_wr_ld != 1) begin
            $display("Error: Expected wr_ld=1 when FIFO becomes not full");
            errors++;
        end
        
        // Set write to CSR to complete the operation
        axi_wr_fb_csr = CSR;
        @(posedge clk);
        @(posedge clk);
        end_test_case();
        
        // Test case 9: Read FIFO Full Handling
        begin_test_case("FSM2: Read FIFO Full Handling");
        // Assert read request
        axi_rd_req = 1;
        @(posedge clk);
        
        // Deassert read request but set read FIFO full
        axi_rd_req = 0;
        axi_rd_full = 1;
        @(posedge clk);
        
        // It should stay in READ_WAIT state with no rd_ld asserted
        if (ctrl_rd_ld != 0) begin
            $display("Error: Expected rd_ld=0 when FIFO is full");
            errors++;
        end
        
        // Now clear the full flag
        axi_rd_full = 0;
        @(posedge clk);
        
        // Now it should assert rd_ld
        if (ctrl_rd_ld != 1) begin
            $display("Error: Expected rd_ld=1 when FIFO becomes not full");
            errors++;
        end
        
        // Set read from CSR and cr to complete the operation
        axi_rd_fb_csr = CSR;
        cr = 1;
        @(posedge clk);
        @(posedge clk);
        end_test_case();
        
    endtask
    
    // Helper tasks for test management
    task begin_test_case(string name);
        test_case++;
        test_name = name;
        $display("\n=== Starting Test Case %0d: %s ===", test_case, test_name);
    endtask
    
    task end_test_case();
        $display("=== Completed Test Case %0d: %s ===\n", test_case, test_name);
    endtask
    
endmodule