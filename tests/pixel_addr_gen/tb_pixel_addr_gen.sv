`timescale 1ns/1ps
`include "common/displayConsts.sv"
`include "common/vgaTimes.sv"
`ifndef tb_pixel_addr_gen
`define tb_pixel_addr_gen


module tb_pixel_addr_gen();

    // DUT signals
    logic clk;
    logic rst;
    logic [H_BITS-1:0] h_cnt;
    logic [V_BITS-1:0] v_cnt;
    logic in_frame;
    logic next;
    logic [PIXEL_ADDR_BITS-1:0] pixel_addr;

    // Instantiate the DUT
    pixel_addr_gen dut (
        .clk(clk),
        .rst(rst),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .in_frame(in_frame),
        .next(next),
        .pixel_addr(pixel_addr)
    );

    // Clock generation
    always begin
        #8 clk = ~clk;  // 60MHz clock
    end

    initial begin
    // Name as needed
        $dumpfile("tb_pixel_addr_gen.vcd");
        $dumpvars(0);
    end

    // Test variables
    int row;
    int col;
    logic [PIXEL_ADDR_BITS-1:0] expected_addr;
    logic [PIXEL_ADDR_BITS-1:0] expected_next_row_base;

    // Test procedure
    initial begin
        // Initialize
        row = 0;
        col = 0;
        clk = 0;
        rst = 1;
        h_cnt = 0;
        v_cnt = 0;
        in_frame = 0;
        next = 0;
        
        // Release reset
        #24 rst = 0;
        
        // Test Full Frame Scanning
        for (int v = 0; v < V_VISIBLE_AREA; v++) begin  
            v_cnt = V_BITS'(v);
            expected_next_row_base = PIXEL_ADDR_BITS'(((v + 1) % V_VISIBLE_AREA) * H_VISIBLE_AREA);
            
            // Test visible part first
            for (int h = 0; h < H_VISIBLE_AREA; h++) begin
                h_cnt = H_BITS'(h);
                in_frame = 1;
                next = 0;
                expected_addr = PIXEL_ADDR_BITS'(v * H_VISIBLE_AREA + h);
                
                // Wait for a clock cycle
                @(posedge clk);
                #1;  // Small delay after clock edge
                
                // Check address when in visible area
                if (pixel_addr !== expected_addr) begin
                    $display("ERROR at v=%0d, h=%0d: Expected addr=%0d, Got=%0d", 
                            v, h, expected_addr, pixel_addr);
                end else begin
                    //$display("OK at v=%0d, h=%0d: addr=%0d", v, h, pixel_addr);
                end
            end
            
            // Now test the horizontal blanking period
            // First clock cycle of blanking - assert next signal
            h_cnt = H_BITS'(H_VISIBLE_AREA);
            in_frame = 0;
            next = 1;  // Trigger update at start of blanking
            
            @(posedge clk);
            #1;
            //$display("H-Blanking starts at v=%0d: next=%0b", v, next);
            
            // Check that pixel_addr now shows the base address for the next row
            // during the rest of the blanking period
            next = 0;  // next is only high for one cycle
            
            for (int h = H_VISIBLE_AREA + 1; h < H_VISIBLE_AREA + 160; h++) begin
                h_cnt = H_BITS'(h);
                @(posedge clk);
                #1;
                
                if (pixel_addr !== expected_next_row_base) begin
                    $display("ERROR in H-Blanking at v=%0d, h=%0d: Expected next row base=%0d, Got=%0d", 
                            v, h, expected_next_row_base, pixel_addr);
                end else begin
                    //$display("OK in H-Blanking at v=%0d, h=%0d: next row base=%0d", v, h, pixel_addr);
                end
            end
        end
        
        // Additional specific test: Reset at end of frame
        // Set to last visible row
        v_cnt = V_BITS'(V_VISIBLE_AREA - 1);
        h_cnt = H_BITS'(H_VISIBLE_AREA);  // Start of blanking
        in_frame = 0;
        next = 1;  // Trigger update
        
        @(posedge clk);
        #1;
        next = 0;
        
        // During the final row's blanking, should have row 0 base address
        for (int h = H_VISIBLE_AREA + 1; h < H_VISIBLE_AREA + 10; h++) begin
            h_cnt = H_BITS'(h);
            @(posedge clk);
            #1;
            
            if (pixel_addr !== 0) begin
                $display("ERROR in last row H-Blanking at h=%0d: Expected row 0 base=0, Got=%0d", 
                        h, pixel_addr);
            end else begin
                //$display("OK in last row H-Blanking at h=%0d: row 0 base=0", h);
            end
        end
        
        // Verify first pixel of new frame
        v_cnt = V_BITS'(0);
        h_cnt = H_BITS'(0);
        in_frame = 1;
        
        @(posedge clk);
        #1;
        
        if (pixel_addr !== 0) begin
            $display("ERROR at frame wrap: Expected addr=0, Got=%0d", pixel_addr);
        end else begin
            $display("OK at frame wrap: addr=0");
        end
        
        // End simulation
        #20 $finish;
    end
    
    // Monitor for debug
    // initial begin
    //     $monitor("Time=%0t: h_cnt=%0d, v_cnt=%0d, in_frame=%0b, next=%0b, pixel_addr=%0d", 
    //              $time, h_cnt, v_cnt, in_frame, next, pixel_addr);
    // end
endmodule

`endif 