`ifndef AVSDDAC
`define AVSDDAC
`timescale 1ns / 1ps

module avsddac( 
  input logic [15:0] VREFH,
  input logic [15:0] VREFL,  
  input logic [5:0] D,
  input logic EN,    
  output logic [15:0] OUT
  );

  logic [6:0] Dext;   
  logic [31:0] temp_calc, vref_diff;
 
  assign Dext = {1'b0, D};

  assign vref_diff = {16'b0, VREFH} - {16'b0, VREFL};
  
  assign temp_calc = ({25'b0, Dext} * vref_diff) / 63;
  assign OUT = VREFL + temp_calc[15:0];

endmodule
`endif