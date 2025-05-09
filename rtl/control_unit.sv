// TODO: camille
`include "common/vga_driver_structs.sv"

import vga_driver_structs::*;

/*
    check the struct defns
    if they dont make sense
*/

module control_unit (
    input logic clk,

    input statuses_t statuses,

    output controls_t controls
    );

endmodule