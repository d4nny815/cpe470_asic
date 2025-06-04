`ifndef TB_AVSDDAC
`define TB_AVSDDAC
`timescale 1ns / 1ps

module tb_avsddac;
    logic EN;
    logic [15:0] VREFH, VREFL;
    logic [5:0] D;
    logic [15:0] OUT;
    
    // For displaying actual voltage values
    real actual_voltage;

    avsddac uut ( 
        .VREFH(VREFH), 
        .VREFL(VREFL), 
        .D(D),
        .EN(EN),
        .OUT(OUT)
    );

    initial begin
        EN = 1'b0;
        #5 EN = 1'b1;
    end

    initial begin
        // Set reference voltages in fixed-point (mV representation)
        VREFH = 16'd3300;  // 3.3V = 3300mV
        VREFL = 16'd0;     // 0.0V = 0mV
    end

    initial begin 
        // Test various 6-bit values
        #10  D = 6'h00;  
        #10  D = 6'h01;  
        #10  D = 6'h0F;  
        #10  D = 6'h1F;  
        #10  D = 6'h2F;  
        #10  D = 6'h3A;  
        #10  D = 6'h3B;  
        #10  D = 6'h3C;  
        #10  D = 6'h3D;  
        #10  D = 6'h3E;  
        #10  D = 6'h3F;  
    end

    // Convert fixed-point output to real voltage for display
    always @(*) begin
        actual_voltage = $itor(OUT) / 1000.0;  // Convert mV to V
    end

    initial begin
        $monitor("Time=%0t, D=6'h%02h (%0d), OUT=%0d mV (%.3f V)", 
                 $time, D, D, OUT, actual_voltage);
    end

    initial begin
        $dumpfile("tb_avsddac.vcd");
        $dumpvars(0, tb_avsddac);
        #200 $finish;
    end
        
endmodule
`endif