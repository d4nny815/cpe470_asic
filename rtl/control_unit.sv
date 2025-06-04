`ifndef CONTROL_UNIT
`define CONTROL_UNIT

`include "vga_driver_structs.svh"

module control_unit (
    input logic clk,
    input statuses_t statuses,
    output controls_t controls
    );

    // VGA TIMING FSM -----------
    typedef enum logic [0:0] {
        INFRAME  = 1'b0,
        OUTFRAME = 1'b1
    } state_t;

    state_t curr_state_1, next_state_1;
    logic fetch_next, next_toggle;


    always_ff @(posedge clk) begin
        if (!statuses.RST_N) begin
            curr_state_1 <= INFRAME;
            fetch_next   <= 0;
        end else begin
            curr_state_1 <= next_state_1;
        end

        if (next_toggle)
            fetch_next   <= ~fetch_next;
    end
    
    always_comb begin
        next_state_1 = curr_state_1;
        
        controls.next = 0;
        controls.vga_fetch = 0;
        controls.vga_re = 0;
        next_toggle = 0;

        case (curr_state_1)
            INFRAME: begin
                controls.vga_re = 1;

                if (statuses.in_frame) begin
                    next_toggle = 1;
                    next_state_1 = INFRAME;
                end else begin
                    next_state_1 = OUTFRAME;
                    controls.next = fetch_next;
                end
             end

            OUTFRAME:  begin
                controls.vga_fetch = 1;
                if (!statuses.in_frame) begin
                    next_state_1 = OUTFRAME; 
                end else begin
                    next_state_1 = INFRAME;
                    controls.vga_re = 1;
                    controls.vga_fetch = 0;
                end
            end

            default:  next_state_1 = INFRAME; 
        endcase
    end

    // FIXME: commented for now
    // R/W FSM
    typedef enum logic [3:0] {
        RESET = 4'd0,
        IDLE = 4'd1,

        WRITE_WAIT = 4'd2,
        WR_FB_WAIT = 4'd3,

        READ_WAIT = 4'd4,
        RD_FB_WAIT = 4'd5,
        RD_CSR_WAIT = 4'd6
    } state_t2;

    state_t2 curr_state_2, next_state_2;

    always_ff @(posedge clk) begin
        if (!statuses.RST_N)
            curr_state_2 <= RESET;
        else
            curr_state_2 <= next_state_2;
    end


    always_comb begin
        controls.reset_n = 1;
        
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
        controls.addr_sel = 1'b0;

        next_state_2 = curr_state_2;

        case (curr_state_2)
            RESET: begin
                controls.reset_n = 0;
                next_state_2 = IDLE;
            end

            IDLE: begin
                // set everything low
                if (statuses.axi_comms.wr_req && statuses.axi_comms.wr_fb_csr == FB) begin
                    controls.wr_re = 1;
                    controls.wr_ld = 1;
                    next_state_2 = WRITE_WAIT;
                end 
                else if (statuses.axi_comms.wr_req && statuses.axi_comms.wr_fb_csr == CSR) begin
                    controls.wr_re = 1;
                    controls.cr_ld = 1;
                end
                else if (statuses.axi_comms.rd_req && statuses.axi_comms.rd_fb_csr == FB) begin
                    controls.rd_re = 1;
                    controls.rd_ld = 1;
                    next_state_2 = READ_WAIT;
                end 
                else if (statuses.axi_comms.rd_req && statuses.axi_comms.rd_fb_csr == CSR) begin
                    controls.rd_re = 1;
                    next_state_2 = RD_CSR_WAIT;
                end 
            end

            WRITE_WAIT: begin
                controls.addr_sel = 0;
                controls.fb_w_r = 1;
                controls.fb_en  = 1;
                next_state_2 = WR_FB_WAIT;
            end

            WR_FB_WAIT: begin
                if (statuses.fb_valid)
                    next_state_2 = IDLE;
            end

            READ_WAIT: begin
                controls.addr_sel = 1;
                controls.fb_w_r = 0;
                controls.fb_en  = 1;
                next_state_2 = RD_FB_WAIT;
                controls.rd_data_sel = 2'b10;
            end

            RD_FB_WAIT: begin
                if (statuses.fb_valid) begin
                    controls.rd_data_sel = 0;
                    controls.rd_we = 1;
                    next_state_2 = IDLE;
                end
            end

            RD_CSR_WAIT: begin
                controls.rd_data_sel = 1; // FIXME: cr and sr diff

                next_state_2 = IDLE;
            end
                   
        default: next_state_2 = RESET;

        endcase

    end

endmodule
`endif