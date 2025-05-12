`timescale 1ns / 1ps

`include "common/vga_driver_structs.sv"

import vga_driver_structs::*;

module control_unit (
    input logic clk,
    input logic fb_valid,
    input logic cr,
    
    // Flattened status signals
    input logic RST_N,                           // Reset signal (active low)
    input logic in_frame,                        // VGA timing in frame signal
    
    // AXI communication status signals
    input logic axi_wr_full,                     // Write FIFO full
    input logic axi_wr_req,                      // Write request
    input fb_csr_t axi_wr_fb_csr,                // Write target (FB or CSR)
    input logic axi_rd_full,                     // Read FIFO full
    input logic axi_rd_req,                      // Read request
    input fb_csr_t axi_rd_fb_csr,                // Read target (FB or CSR)
    
    // Flattened control signals
    output logic ctrl_reset_n,                   // Reset signal output
    output logic ctrl_next,                      // Next frame signal
    output logic ctrl_vga_fetch,                 // VGA fetch signal
    output logic ctrl_wr_ld,                     // Write load
    output logic ctrl_rd_ld,                     // Read load
    output logic ctrl_cr_ld,                     // Control register load
    output logic ctrl_fb_w_r,                    // Frame buffer write/read
    output logic ctrl_fb_en,                     // Frame buffer enable
    output logic ctrl_wr_re,                     // Write request enable
    output logic ctrl_rd_re,                     // Read request enable
    output logic ctrl_rd_we,                     // Read write enable
    output logic [1:0] ctrl_rd_data_sel,         // Read data select
    
    output logic addr_sel                        // Address select
);

    // Create struct bundles for compatibility with original code
    statuses_t statuses;
    controls_t controls;

    // Connect flattened inputs to struct
    assign statuses.RST_N = RST_N;
    assign statuses.in_frame = in_frame;
    assign statuses.axi_comms.wr_full = axi_wr_full;
    assign statuses.axi_comms.wr_req = axi_wr_req;
    assign statuses.axi_comms.wr_fb_csr = axi_wr_fb_csr;
    assign statuses.axi_comms.rd_full = axi_rd_full;
    assign statuses.axi_comms.rd_req = axi_rd_req;
    assign statuses.axi_comms.rd_fb_csr = axi_rd_fb_csr;

    // Connect struct outputs to flattened outputs
    assign ctrl_reset_n = controls.reset_n;
    assign ctrl_next = controls.next;
    assign ctrl_vga_fetch = controls.vga_fetch;
    assign ctrl_wr_ld = controls.wr_ld;
    assign ctrl_rd_ld = controls.rd_ld;
    assign ctrl_cr_ld = controls.cr_ld;
    assign ctrl_fb_w_r = controls.fb_w_r;
    assign ctrl_fb_en = controls.fb_en;
    assign ctrl_wr_re = controls.wr_re;
    assign ctrl_rd_re = controls.rd_re;
    assign ctrl_rd_we = controls.rd_we;
    assign ctrl_rd_data_sel = controls.rd_data_sel;

    // VGA TIMING FSM -----------

    typedef enum logic [0:0] {
        INFRAME  = 1'b0,
        OUTFRAME = 1'b1
    } state_t;

    state_t curr_state_1, next_state_1;

    always_ff @(posedge clk or negedge statuses.RST_N) begin
        if (!statuses.RST_N) begin
            curr_state_1 <= INFRAME;
            controls.reset_n = 1;
        end else begin
            curr_state_1 <= next_state_1;
        end
    end

    always_comb begin
        controls.next = 0;
        controls.vga_fetch = 0;
        next_state_1 = curr_state_1;

        case (curr_state_1)
            INFRAME: begin
                if (statuses.in_frame) begin
                    next_state_1 = INFRAME;
                end else begin
                    next_state_1 = OUTFRAME;
                    controls.next = 1;
                end
             end

            OUTFRAME:  begin
                controls.vga_fetch = 1;
                if (!statuses.in_frame) begin
                    next_state_1 = OUTFRAME; 
                end else begin
                    next_state_1 = INFRAME;
                    controls.vga_fetch = 0;
                end
            end

            default:  next_state_1 = INFRAME; 
        endcase
    end

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

    state_t2 curr_state_2, next_state_2;

    always_ff @(posedge clk or negedge statuses.RST_N) begin
        if (!statuses.RST_N)
            curr_state_2 <= IDLE;
        else
            curr_state_2 <= next_state_2;
    end


    always_comb begin
        // Note: Do not reset all signals here, as it would override the VGA FSM outputs
        controls.wr_ld = 1'b0;
        controls.rd_ld = 1'b0;
        controls.cr_ld = 1'b0;
        controls.fb_w_r = 1'b0;
        controls.fb_en = 1'b0;
        controls.wr_re = 1'b0;
        controls.rd_re = 1'b0;
        controls.rd_we = 1'b0;
        controls.rd_data_sel = 2'b00;
        addr_sel = 0;

        next_state_2 = curr_state_2;

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

                    if (statuses.axi_comms.wr_fb_csr == FB) begin
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
                    if (statuses.axi_comms.rd_fb_csr == FB) begin
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

        endcase

    end

endmodule