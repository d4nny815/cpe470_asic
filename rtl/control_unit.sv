// TODO: camille
`include "common/vga_driver_structs.sv"

import vga_driver_structs::*;

/*
    check the struct defns
    if they dont make sense
*/

module control_unit (
    input logic clk,
    input logic fb_valid,
    input logic cr,
    input statuses_t statuses,
    output controls_t controls,
    output logic addr_sel,
    output logic rd_we
    );

    // // VGA TIMING FSM -----------

    // typedef enum logic [0:0] {
    //     INFRAME  = 1'b0,
    //     OUTFRAME = 1'b1
    // } state_t;

    // state_t curr_state_1, next_state_1;

    // always_ff @(posedge clk or negedge RST_N) begin
    //     if (!RST_N)
    //         curr_state_1 <= INFRAME;
    //     else
    //         curr_state_1 <= next_state_1;
    // end

    // always_comb begin
    //     controls.next = 0;
    //     controls.vga_fetch = 0;
    //     next_state_1 = curr_state_1;

    //     case (curr_state_1)
    //         INFRAME: begin
    //             if (statuses.in_frame) begin
    //                 next_state_1 = INFRAME;
    //             end else begin
    //                 next_state_1 = OUTFRAME;
    //                 controls.next = 1;
    //             end
    //          end

    //         OUTFRAME:  begin
    //             controls.vga_fetch = 1;
    //             if (!statuses.in_frame) begin
    //                 next_state_1 = OUTFRAME; 
    //             end else begin
    //                 next_state_1 = INFRAME;
    //                 controls.vga_fetch = 0;
    //             end
    //         end

    //         default:  next_state_1 = INFRAME; 
    //     endcase
    // end

    // // R/W FSM
    // typedef enum logic [1:0] {
    //     IDLE  = 2'b00,
    //     WRITE = 2'b01,
    //     READ  = 2'b10,
    //     RESET = 2'b11
    // } state_t2;

    // state_t2 curr_state_2, next_state_2;

    // always_ff @(posedge clk or negedge RST_N) begin
    // if (!RST_N)
    //     curr_state_2 <= RESET;
    // else
    //     curr_state_2 <= next_state_2;
    // end

    // always_comb begin
    //     // reset all signals
    //     controls.wr_ld = 0; 
    //     controls.rd_ld = 0;
    //     controls.cr_ld = 0;
    //     controls.fb_w_r = 0;
    //     controls.fb_en = 0;
    //     controls.wr_re = 0;
    //     controls.rd_re = 0;
    //     controls.rd_we = 0;
    //     controls.rd_data_sel = '0;
    //     controls.rd_we = 0;

    //     addr_sel = 0;
    //     rd_we = 0;

    //     next_state_2 = curr_state_2;

    //     case (curr_state_2)
    //         RESET: begin
    //             reset_n = 1;
    //         end

    //         IDLE: begin
    //             // set everything low
    //             if (statuses.wr_req)
    //                 next_state_2 = WRITE;
    //                 controls.wr_re = 1;

    //             else if (statuses.rd_req) begin
    //                 next_state_2 = READ;
    //                 controls.rd_re = 1;

    //             end else
    //                 next_state_2 = IDLE;
    //         end

    //         WRITE: begin
    //             if (statuses.wr_fb_csr) begin
    //                 // write to frame buffer
    //                 while (statuses.wr_full) begin
    //                     // wait til full goes low (write register is open then)
    //                 end
    //                 controls.wr_ld = 1;
    //                 addr_sel = 0; // select write address
    //                 while (!fb_valid) begin
    //                     // wait til FB not busy
    //                 end
    //                 // enable write on frame buffer
    //                 controls.fb_w_r = 1;
    //                 controls.fb_en = 1;
    //             end else begin
    //                 // write to CR
    //                 controls.cr_ld;
    //             end
    //             next_state_2 = IDLE;
    //         end

    //         READ: begin
    //             if (statuses.rd_fb_csr) begin
    //                 // read from frame buffer
    //                 controls.rd_data_sel = 2'b01;
    //             end else begin
    //                 if (cr) begin
    //                     // read from control
    //                     controls.rd_data_sel = 2'b10;
    //                 end else begin
    //                     // read from status
    //                     controls.rd_data_sel = 2'101;
    //                 end
    //             end
    //             rd_we = 1;
    //             next_state_2 = IDLE;
    //         end

    //         default: // reset signals and set state to IDLE

    //     endcase

    // end





endmodule