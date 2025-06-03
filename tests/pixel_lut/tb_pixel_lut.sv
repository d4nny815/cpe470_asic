`ifndef tb_pixel_lut
`define tb_pixel_lut
`timescale 1ns / 1ps
`include "displayConsts.svh"

module tb_pixel_lut();

    // Test inputs
    logic [COLOR_LUT_BITS-1:0] index;
    logic mode;
    logic blackout;
    
    // Test outputs
    logic [COLOR_BITS-1:0] color;
    
    // Expected outputs for verification
    logic [COLOR_BITS-1:0] expected_color;
    
    // Instantiate device under test (DUT)
    pixel_lut_top DUT (
        .index(index),
        .mode(mode),
        .blackout(blackout),
        .color(color)
    );
    
    initial begin
        // Name as needed
        $dumpfile("tb_pixel_lut.vcd");
        $dumpvars(1, tb_pixel_lut);
    end

    initial begin
        #100000; // 100 microseconds in simulation time
        $display("ERROR: Simulation timeout reached.");
        $finish;
    end
    
    // Test case counter and error counter
    int test_count = 0;
    int error_count = 0;
    
    // For storing test descriptions
    string test_description;
    
    // Function to verify and report test cases
    function void verify_color(input string desc);
        test_count++;
        if (color !== expected_color) begin
            $display("ERROR: Test %0d (%s) failed", test_count, desc);
            $display("  Expected: %h, Got: %h", expected_color, color);
            error_count++;
        end else begin
            $display("PASS: Test %0d (%s)", test_count, desc);
        end
    endfunction
    
    // Reference color lookup tables for verification
    function logic [COLOR_BITS-1:0] get_color16(input logic [3:0] idx);
        case (idx)
            4'd0  : return 18'h00000; // black 
            4'd1  : return 18'h00003; // blue 
            4'd2  : return 18'h00300; // green 
            4'd3  : return 18'h00303; // cyan 
            4'd4  : return 18'h03000; // red 
            4'd5  : return 18'h03003; // magenta
            4'd6  : return 18'h03100; // brown (dark yellow) 
            4'd7  : return 18'h03333; // light gray 
            4'd8  : return 18'h01515; // dark gray 
            4'd9  : return 18'h0151F; // light blue
            4'd10 : return 18'h01F15; // light green 
            4'd11 : return 18'h01F1F; // light cyan
            4'd12 : return 18'h03F15; // light red 
            4'd13 : return 18'h03F1F; // light magenta 
            4'd14 : return 18'h03F3F; // yellow 
            4'd15 : return 18'h3FFFF; // white 
            default: return 18'h00000;
        endcase
    endfunction
    
    function logic [COLOR_BITS-1:0] get_color256(input logic [7:0] idx);
        logic [5:0] r, g, b;
        int i, r_level, g_level, b_level, gray_level;
        logic [7:0] gray8;
        logic [5:0] gray6;
        
        if (idx < 8'd16) begin
            return get_color16(idx[3:0]);
        end else if (idx < 8'd232) begin
            // 6x6x6 RGB cube
            i = int'(idx) - 16;
            r_level = i / 36;
            g_level = (i / 6) % 6;
            b_level = i % 6;

            case (r_level)
                0: r = 6'd0;
                1: r = 6'd13;
                2: r = 6'd25;
                3: r = 6'd38;
                4: r = 6'd50;
                5: r = 6'd63;
                default: r = 6'd0;
            endcase
            
            case (g_level)
                0: g = 6'd0;
                1: g = 6'd13;
                2: g = 6'd25;
                3: g = 6'd38;
                4: g = 6'd50;
                5: g = 6'd63;
                default: g = 6'd0;
            endcase
            
            case (b_level)
                0: b = 6'd0;
                1: b = 6'd13;
                2: b = 6'd25;
                3: b = 6'd38;
                4: b = 6'd50;
                5: b = 6'd63;
                default: b = 6'd0;
            endcase

            return {r, g, b};
        end else begin
            // Grayscale range
            gray_level = int'(idx) - 232;
            gray8 = 8'(gray_level * 10 + 8);
            gray6 = gray8[7:2]; // convert 8-bit gray to 6-bit by taking top 6 bits

            return {gray6, gray6, gray6};
        end
    endfunction
    
    // Initial block for test sequence
    initial begin
        $display("Starting pixel_lut_top testbench...");
        
        // Initialize inputs
        index = 0;
        mode = 0;
        blackout = 0;
        
        // Give some time for signals to stabilize
        #5;
        
        // ========== TEST 16-COLOR MODE ==========
        mode = 0; // 16-color mode
        blackout = 0; // Blackout off
        
        // Test all 16 colors in 16-color mode
        for (byte i = 0; i < 16; i++) begin
            index = i;
            #5; // Wait for combinational logic to settle
            expected_color = get_color16(index[3:0]);
            test_description = $sformatf("16-color mode, index=%0d", i);
            verify_color(test_description);
            #5;
        end
        
        // ========== TEST 256-COLOR MODE ==========
        mode = 1; // 256-color mode
        blackout = 0; // Blackout off
        
        // Test a sample of colors from different ranges in 256-color mode
        // First 16 colors (same as 16-color mode)
        for (byte i = 0; i < 16; i++) begin
            index = i;
            #5;
            expected_color = get_color256(index);
            test_description = $sformatf("256-color mode, first 16 colors, index=%0d", i);
            verify_color(test_description);
            #5;
        end
        
        // Sample from RGB cube (using individual test cases instead of an array)
        // Test several specific indices from the RGB cube
        index = 16;
        #5;
        expected_color = get_color256(index);
        test_description = $sformatf("256-color mode, RGB cube, index=%0d", index);
        verify_color(test_description);
        #5;
        
        index = 22;
        #5;
        expected_color = get_color256(index);
        test_description = $sformatf("256-color mode, RGB cube, index=%0d", index);
        verify_color(test_description);
        #5;
        
        index = 34;
        #5;
        expected_color = get_color256(index);
        test_description = $sformatf("256-color mode, RGB cube, index=%0d", index);
        verify_color(test_description);
        #5;
        
        index = 46;
        #5;
        expected_color = get_color256(index);
        test_description = $sformatf("256-color mode, RGB cube, index=%0d", index);
        verify_color(test_description);
        #5;
        
        index = 87;
        #5;
        expected_color = get_color256(index);
        test_description = $sformatf("256-color mode, RGB cube, index=%0d", index);
        verify_color(test_description);
        #5;
        
        index = 123;
        #5;
        expected_color = get_color256(index);
        test_description = $sformatf("256-color mode, RGB cube, index=%0d", index);
        verify_color(test_description);
        #5;
        
        index = 159;
        #5;
        expected_color = get_color256(index);
        test_description = $sformatf("256-color mode, RGB cube, index=%0d", index);
        verify_color(test_description);
        #5;
        
        index = 195;
        #5;
        expected_color = get_color256(index);
        test_description = $sformatf("256-color mode, RGB cube, index=%0d", index);
        verify_color(test_description);
        #5;
        
        index = 231;
        #5;
        expected_color = get_color256(index);
        test_description = $sformatf("256-color mode, RGB cube, index=%0d", index);
        verify_color(test_description);
        #5;
        
        // Sample from grayscale range
        for (byte unsigned i = 232; i < 255; i ++) begin
            index = i;
            #5;
            expected_color = get_color256(index);
            test_description = $sformatf("256-color mode, grayscale, index=%0d", i);
            verify_color(test_description);
            #5;
        end
        
        // ========== TEST BLACKOUT FEATURE ==========
        // Test blackout with 16-color mode
        mode = 0;
        blackout = 1;
        for (byte i = 0; i < 16; i += 3) begin
            index = i;
            #5;
            expected_color = 18'h0000; // All colors should be black in blackout mode
            test_description = $sformatf("Blackout with 16-color mode, index=%0d", i);
            verify_color(test_description);
            #5;
        end
        
        // // Test blackout with 256-color mode
        mode = 1;
        blackout = 1;
        for (byte unsigned i = 0; i < 255; i += 5) begin
            index = i;
            #5;
            expected_color = 18'h0000; // All colors should be black in blackout mode
            test_description = $sformatf("Blackout with 256-color mode, index=%0d", i);
            verify_color(test_description);
            #5;
        end
        
        // ========== TEST MODE SWITCHING ==========
        // Test switching between modes with the same index
        blackout = 0;
        for (byte i = 0; i < 16; i += 2) begin
            index = i;
            
            // Test 16-color mode
            mode = 0;
            #5;
            expected_color = get_color16(index[3:0]);
            test_description = $sformatf("Mode switching - 16-color mode, index=%0d", i);
            verify_color(test_description);
            #5;
            
            // Test 256-color mode with same index
            mode = 1;
            #5;
            expected_color = get_color256(index);
            test_description = $sformatf("Mode switching - 256-color mode, index=%0d", i);
            verify_color(test_description);
            #5;
        end
        
        // ========== SUMMARIZE RESULTS ==========
        if (error_count == 0) begin
            $display("All %0d tests PASSED!", test_count);
        end else begin
            $display("%0d out of %0d tests FAILED!", error_count, test_count);
        end
        
        $finish;
    end

endmodule
`endif