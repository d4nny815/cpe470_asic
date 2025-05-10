// TODO: camille
`include "common/vga_driver_structs.sv"

import vga_driver_structs::*;

/*
    check the struct defns
    if they dont make sense
*/

module control_unit (
    input logic RST_N,
    input logic clk,
    input logic fb_valid,
    input logic cr,
    input statuses_t statuses,
    output controls_t controls,
    output logic addr_sel
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

    // R/W FSM
    typedef enum logic [3:0] {
        RESET = 4'd0,
        IDLE = 4'd1,

        WRITE_WAIT = 4'd2,
        WR_FB_WAIT = 4'd3,
        WR_FB = 4'd4,
        WR_CSR = 4'd5,

        READ_WAIT = 4'd6,
        RD_FB_WAIT = 4'd7,
        RD_FB = 4'd8,
        RD_CNTL = 4'd9,
        RD_STATUS = 4'd10

    } state_t2;

    // state_t2 curr_state_2, next_state_2;

    // always_ff @(posedge clk or negedge RST_N) begin
    // if (!RST_N)
    //     curr_state_2 <= RESET;
    // else
    //     curr_state_2 <= next_state_2;
    // end

    always_comb begin
        // reset all signals
        controls = '0;
        addr_sel = 0;

    //     next_state_2 = curr_state_2;

        case (curr_state_2)

            RESET: begin
                controls.reset_n = 1;
                next_state_2 = IDLE;
            end

            IDLE: begin
                // set everything low
                if (statuses.axi_comms.wr_req) begin
                    next_state_2 = WRITE_WAIT;
                    controls.wr_re = 1;
                end else if (statuses.axi_comms.rd_req) begin
                    next_state_2 = READ_WAIT;
                    controls.rd_re = 1;
                end else
                    next_state_2 = IDLE;
            end

            WRITE_WAIT: begin
                if (statuses.axi_comms.wr_full) begin
                    next_state_2 = WRITE_WAIT;
                end else begin
                    controls.wr_ld = 1;

                    if (statuses.axi_comms.wr_fb_csr) begin
                        next_state_2 = WR_FB_WAIT;
                    end else begin
                        next_state_2 = WR_CSR;
                    end
                end
            end

            WR_FB_WAIT: begin
                addr_sel = 0;
                if (fb_valid) begin
                    next_state_2 = WR_FB;
                end else begin
                    next_state_2 = WR_FB_WAIT;
                end
            end

            WR_FB: begin
                controls.fb_w_r = 1;
                controls.fb_en = 1;
                next_state_2 = IDLE;
            end

            WR_CSR: begin
                controls.cr_ld = 1;
                next_state_2 = IDLE;
            end


            READ_WAIT: begin
                if (!statuses.axi_comms.rd_full) begin
                    controls.rd_ld = 1;
                    if (statuses.axi_comms.rd_fb_csr) begin
                        next_state_2 = RD_FB_WAIT;
                    end else begin
                        if (cr) begin
                            next_state_2 = RD_CNTL;
                        end else begin
                            next_state_2 = RD_STATUS;
                        end
                    end
                end else begin
                    next_state_2 = READ_WAIT;
                end
            end

            RD_FB_WAIT: begin
                addr_sel = 1'b1;
                if (fb_valid) begin
                    next_state_2 = RD_FB;
                end else begin
                    next_state_2 = RD_FB_WAIT;
                end
            end

            RD_FB: begin
                controls.fb_w_r = 0;
                controls.fb_en = 1;
                controls.rd_we = 1;
                controls.rd_data_sel = 2'b01;
                next_state_2 = IDLE;
            end

            RD_CNTL: begin
                controls.rd_data_sel = 2'b10;
                controls.rd_we = 1;
                next_state_2 = IDLE;
            end

            RD_STATUS: begin
                controls.rd_data_sel = 2'b11;
                controls.rd_we = 1;
                next_state_2 = IDLE;
            end
                   
        default: next_state_2 = IDLE;

    //     endcase

    // end





endmodule